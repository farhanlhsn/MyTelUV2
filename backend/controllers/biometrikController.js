const prisma = require('../utils/prisma');
const asyncHandler = require('express-async-handler');
const FormData = require('form-data');
const axios = require('axios');
const axiosRetry = require('axios-retry').default;
const fs = require('fs');
const { uploadFile, deleteFile } = require('../utils/r2FileHandler');
const embeddingCache = require('../utils/embeddingCache');
const { logAudit, BIOMETRIK_ACTIONS } = require('../utils/auditLogger');

const PYTHON_SERVICE_URL = process.env.PYTHON_SERVICE_URL || 'http://localhost:5051';
const PYTHON_SERVICE_TIMEOUT = parseInt(process.env.PYTHON_SERVICE_TIMEOUT || '10000');
const SIMILARITY_THRESHOLD = parseFloat(process.env.FACE_SIMILARITY_THRESHOLD || '0.6');

// Configure axios retry with exponential backoff
axiosRetry(axios, {
    retries: 3,
    retryDelay: axiosRetry.exponentialDelay,
    retryCondition: (error) =>
        axiosRetry.isNetworkOrIdempotentRequestError(error) ||
        error.code === 'ECONNABORTED',
    onRetry: (retryCount, error, requestConfig) => {
        console.log(`[PythonService] Retry attempt ${retryCount} for ${requestConfig.url}: ${error.message}`);
    }
});

/**
 * Helper function to call Python service with retry and timeout
 */
const callPythonService = async (endpoint, formData) => {
    try {
        const response = await axios.post(`${PYTHON_SERVICE_URL}${endpoint}`, formData, {
            headers: formData.getHeaders ? formData.getHeaders() : { 'Content-Type': 'application/json' },
            maxContentLength: Infinity,
            maxBodyLength: Infinity,
            timeout: PYTHON_SERVICE_TIMEOUT
        });
        return response.data;
    } catch (error) {
        console.error('Python service error:', error.response?.data || error.message);
        throw new Error(error.response?.data?.error || 'Face recognition service unavailable');
    }
};

/**
 * @desc    Add biometric data (register face)
 * @route   POST /api/biometrik/add
 * @access  Protected
 */
exports.addBiometrik = asyncHandler(async (req, res) => {
    const { id_user } = req.body;

    if (!id_user) {
        return res.status(400).json({
            status: 'error',
            message: 'id_user is required'
        });
    }

    if (!req.file) {
        return res.status(400).json({
            status: 'error',
            message: 'Image file is required'
        });
    }

    // Check if user exists
    const user = await prisma.user.findUnique({
        where: { id_user: parseInt(id_user) }
    });

    if (!user) {
        return res.status(404).json({
            status: 'error',
            message: 'User not found'
        });
    }

    // Check if biometric already exists
    const existingBio = await prisma.dataBiometrik.findUnique({
        where: { id_user: parseInt(id_user) }
    });

    if (existingBio && !existingBio.deletedAt) {
        return res.status(400).json({
            status: 'error',
            message: 'Biometric data already exists for this user. Use edit endpoint to update.'
        });
    }

    try {
        // Call Python service to detect face and extract embedding
        const formData = new FormData();
        formData.append('image', fs.createReadStream(req.file.path));

        const faceResult = await callPythonService('/detect-face', formData);

        if (!faceResult.success) {
            // Clean up uploaded file
            fs.unlinkSync(req.file.path);
            return res.status(400).json({
                status: 'error',
                message: faceResult.error
            });
        }

        // Upload photo to R2
        const fileBuffer = fs.readFileSync(req.file.path);
        const r2Result = await uploadFile(
            fileBuffer,
            req.file.originalname,
            req.file.mimetype,
            'biometric-faces'
        );

        // Clean up uploaded file
        fs.unlinkSync(req.file.path);

        // Save to database
        const biometrik = await prisma.dataBiometrik.upsert({
            where: { id_user: parseInt(id_user) },
            update: {
                face_embedding: faceResult.embedding,
                photo_url: r2Result.fileUrl,
                updatedAt: new Date(),
                deletedAt: null
            },
            create: {
                id_user: parseInt(id_user),
                face_embedding: faceResult.embedding,
                photo_url: r2Result.fileUrl
            }
        });

        // Invalidate cache after adding new biometric
        embeddingCache.invalidateCache();

        // Audit log
        logAudit({
            action: BIOMETRIK_ACTIONS.ADD,
            performedBy: req.user.id_user,
            targetUserId: parseInt(id_user),
            details: `Added biometric data with face_score: ${faceResult.face_score}`,
            ip: req.ip
        });

        res.status(201).json({
            status: 'success',
            message: 'Biometric data registered successfully',
            data: {
                id_biometrik: biometrik.id_biometrik,
                id_user: biometrik.id_user,
                photo_url: biometrik.photo_url,
                face_score: faceResult.face_score,
                createdAt: biometrik.createdAt
            }
        });

    } catch (error) {
        // Clean up file if exists
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        throw error;
    }
});

/**
 * @desc    Delete biometric data
 * @route   DELETE /api/biometrik/delete/:id_user
 * @access  Protected
 */
exports.deleteBiometrik = asyncHandler(async (req, res) => {
    const { id_user } = req.params;

    const biometrik = await prisma.dataBiometrik.findUnique({
        where: { id_user: parseInt(id_user) }
    });

    if (!biometrik || biometrik.deletedAt) {
        return res.status(404).json({
            status: 'error',
            message: 'Biometric data not found'
        });
    }

    // Soft delete
    await prisma.dataBiometrik.update({
        where: { id_user: parseInt(id_user) },
        data: { deletedAt: new Date() }
    });

    // Invalidate cache after deleting biometric
    embeddingCache.invalidateCache();

    // Audit log
    logAudit({
        action: BIOMETRIK_ACTIONS.DELETE,
        performedBy: req.user.id_user,
        targetUserId: parseInt(id_user),
        details: 'Biometric data soft deleted',
        ip: req.ip
    });

    // Optional: Delete from R2 (uncomment if you want to actually delete)
    // if (biometrik.photo_url) {
    //     const fileKey = biometrik.photo_url.split('.r2.dev/')[1];
    //     await deleteFile(fileKey);
    // }

    res.status(200).json({
        status: 'success',
        message: 'Biometric data deleted successfully'
    });
});

/**
 * @desc    Edit biometric data (update face)
 * @route   PUT /api/biometrik/edit/:id_user
 * @access  Protected
 */
exports.editBiometrik = asyncHandler(async (req, res) => {
    const { id_user } = req.params;

    if (!req.file) {
        return res.status(400).json({
            status: 'error',
            message: 'Image file is required'
        });
    }

    const biometrik = await prisma.dataBiometrik.findUnique({
        where: { id_user: parseInt(id_user) }
    });

    if (!biometrik || biometrik.deletedAt) {
        return res.status(404).json({
            status: 'error',
            message: 'Biometric data not found'
        });
    }

    try {
        // Call Python service to detect face and extract embedding
        const formData = new FormData();
        formData.append('image', fs.createReadStream(req.file.path));

        const faceResult = await callPythonService('/detect-face', formData);

        if (!faceResult.success) {
            fs.unlinkSync(req.file.path);
            return res.status(400).json({
                status: 'error',
                message: faceResult.error
            });
        }

        // Upload new photo to R2
        const fileBuffer = fs.readFileSync(req.file.path);
        const r2Result = await uploadFile(
            fileBuffer,
            req.file.originalname,
            req.file.mimetype,
            'biometric-faces'
        );

        // Clean up uploaded file
        fs.unlinkSync(req.file.path);

        // Delete old photo from R2 (optional)
        // if (biometrik.photo_url) {
        //     const fileKey = biometrik.photo_url.split('.r2.dev/')[1];
        //     await deleteFile(fileKey);
        // }

        // Update in database
        const updatedBiometrik = await prisma.dataBiometrik.update({
            where: { id_user: parseInt(id_user) },
            data: {
                face_embedding: faceResult.embedding,
                photo_url: r2Result.fileUrl,
                updatedAt: new Date()
            }
        });

        // Invalidate cache after editing biometric
        embeddingCache.invalidateCache();

        // Audit log
        logAudit({
            action: BIOMETRIK_ACTIONS.EDIT,
            performedBy: req.user.id_user,
            targetUserId: parseInt(id_user),
            details: `Updated biometric data with face_score: ${faceResult.face_score}`,
            ip: req.ip
        });

        res.status(200).json({
            status: 'success',
            message: 'Biometric data updated successfully',
            data: {
                id_biometrik: updatedBiometrik.id_biometrik,
                id_user: updatedBiometrik.id_user,
                photo_url: updatedBiometrik.photo_url,
                face_score: faceResult.face_score,
                updatedAt: updatedBiometrik.updatedAt
            }
        });

    } catch (error) {
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        throw error;
    }
});

/**
 * @desc    Verify face (single face recognition)
 * @route   POST /api/biometrik/verify
 * @access  Protected
 */
exports.verifyWajah = asyncHandler(async (req, res) => {
    if (!req.file) {
        return res.status(400).json({
            status: 'error',
            message: 'Image file is required'
        });
    }

    try {
        // Detect face in uploaded image
        const formData = new FormData();
        formData.append('image', fs.createReadStream(req.file.path));

        const faceResult = await callPythonService('/detect-face', formData);

        // Clean up uploaded file
        fs.unlinkSync(req.file.path);

        if (!faceResult.success) {
            return res.status(400).json({
                status: 'error',
                message: faceResult.error
            });
        }

        // Role-based verification:
        // - ADMIN: can verify against ALL users (search entire database)
        // - DOSEN/MAHASISWA: can only verify their OWN biometric data (prevent abuse)
        const whereClause = {
            deletedAt: null
        };

        // If not ADMIN, restrict to only user's own biometric data
        if (req.user.role !== 'ADMIN') {
            whereClause.id_user = req.user.id_user;
        }

        // Get biometric data based on role
        // For ADMIN, use cache; for others, filter from cache or query directly
        let allBiometrics;
        if (req.user.role === 'ADMIN') {
            allBiometrics = await embeddingCache.getAllEmbeddings();
        } else {
            // For non-admin, get from cache and filter, or query directly for single user
            const cachedData = await embeddingCache.getAllEmbeddings();
            allBiometrics = cachedData.filter(b => b.id_user === req.user.id_user);
        }

        if (allBiometrics.length === 0) {
            const message = req.user.role === 'ADMIN'
                ? 'No registered faces in database'
                : 'You have not registered your biometric data yet';

            return res.status(200).json({
                status: 'success',
                matched: false,
                message: message
            });
        }

        // Find best match
        const matchResult = await callPythonService('/find-match', {
            target_embedding: faceResult.embedding,
            embeddings_list: allBiometrics.map(b => b.face_embedding)
        });

        if (matchResult.error) {
            throw new Error(matchResult.error);
        }

        if (matchResult.is_match) {
            const matchedBiometrik = allBiometrics[matchResult.best_match_index];

            res.status(200).json({
                status: 'success',
                matched: true,
                data: {
                    id_user: matchedBiometrik.user.id_user,
                    nama: matchedBiometrik.user.nama,
                    username: matchedBiometrik.user.username,
                    role: matchedBiometrik.user.role,
                    similarity: matchResult.similarity,
                    confidence: matchResult.similarity > 0.8 ? 'high' : matchResult.similarity > 0.7 ? 'medium' : 'low'
                }
            });
        } else {
            res.status(200).json({
                status: 'success',
                matched: false,
                message: 'No matching face found',
                best_similarity: matchResult.similarity
            });
        }

    } catch (error) {
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        throw error;
    }
});

/**
 * @desc    Scan multiple faces (CCTV/classroom)
 * @route   POST /api/biometrik/scan
 * @access  Protected
 */
exports.scanWajah = asyncHandler(async (req, res) => {
    const { id_kelas } = req.body;

    if (!req.file) {
        return res.status(400).json({
            status: 'error',
            message: 'Image file is required'
        });
    }

    try {
        // Detect multiple faces
        const formData = new FormData();
        formData.append('image', fs.createReadStream(req.file.path));

        const facesResult = await callPythonService('/detect-multiple', formData);

        // Clean up uploaded file
        fs.unlinkSync(req.file.path);

        if (!facesResult.success) {
            return res.status(400).json({
                status: 'error',
                message: facesResult.error
            });
        }

        // Get all active biometric data from cache
        const allBiometrics = await embeddingCache.getAllEmbeddings();

        if (allBiometrics.length === 0) {
            return res.status(200).json({
                status: 'success',
                data: {
                    total_faces_detected: facesResult.count,
                    identified_users: 0,
                    unidentified_count: facesResult.count,
                    users: []
                }
            });
        }

        // Match each detected face using parallel processing
        const embeddings_list = allBiometrics.map(b => b.face_embedding);

        // Process all faces in parallel for better performance
        const matchPromises = facesResult.faces.map(face =>
            callPythonService('/find-match', {
                target_embedding: face.embedding,
                embeddings_list: embeddings_list
            }).then(matchResult => ({ matchResult, face }))
                .catch(err => ({ error: err, face }))
        );

        const matchResults = await Promise.all(matchPromises);

        const identifiedUsers = [];
        for (const { matchResult, face, error } of matchResults) {
            if (error) {
                console.error('Face match error:', error.message);
                continue;
            }
            if (matchResult.is_match) {
                const matchedBiometrik = allBiometrics[matchResult.best_match_index];
                identifiedUsers.push({
                    id_user: matchedBiometrik.user.id_user,
                    nama: matchedBiometrik.user.nama,
                    username: matchedBiometrik.user.username,
                    role: matchedBiometrik.user.role,
                    similarity: matchResult.similarity,
                    bbox: face.bbox,
                    confidence: matchResult.similarity > 0.8 ? 'high' : matchResult.similarity > 0.7 ? 'medium' : 'low'
                });
            }
        }

        res.status(200).json({
            status: 'success',
            data: {
                total_faces_detected: facesResult.count,
                identified_users: identifiedUsers.length,
                unidentified_count: facesResult.count - identifiedUsers.length,
                users: identifiedUsers,
                ...(id_kelas && { id_kelas: parseInt(id_kelas) })
            }
        });

    } catch (error) {
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        throw error;
    }
});

/**
 * Haversine distance helper
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000; // meter
    const toRad = deg => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

/**
 * @desc    Biometric attendance - verify face + check session + check location + mark present
 * @route   POST /api/biometrik/absen
 * @access  Protected (MAHASISWA)
 */
exports.biometrikAbsen = asyncHandler(async (req, res) => {
    const { latitude, longitude } = req.body;
    const id_user = req.user.id_user;

    if (!req.file) {
        return res.status(400).json({
            status: 'error',
            message: 'Image file is required'
        });
    }

    // Validate coordinates
    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        fs.unlinkSync(req.file.path);
        return res.status(400).json({
            status: 'error',
            message: 'Invalid coordinates'
        });
    }

    try {
        // Step 1: Verify face
        const formData = new FormData();
        formData.append('image', fs.createReadStream(req.file.path));
        const faceResult = await callPythonService('/detect-face', formData);

        fs.unlinkSync(req.file.path);

        if (!faceResult.success) {
            return res.status(400).json({
                status: 'error',
                message: faceResult.error || 'Face detection failed'
            });
        }

        // Get user's biometric data
        const userBiometric = await prisma.dataBiometrik.findUnique({
            where: { id_user },
            include: { user: { select: { id_user: true, nama: true, username: true } } }
        });

        if (!userBiometric || userBiometric.deletedAt) {
            return res.status(400).json({
                status: 'error',
                message: 'Anda belum terdaftar biometrik. Hubungi admin untuk pendaftaran.'
            });
        }

        // Compare embeddings
        const matchResult = await callPythonService('/find-match', {
            target_embedding: faceResult.embedding,
            embeddings_list: [userBiometric.face_embedding]
        });

        if (!matchResult.is_match) {
            return res.status(400).json({
                status: 'error',
                message: 'Wajah tidak cocok',
                similarity: matchResult.similarity
            });
        }

        // Step 2: Get user's enrolled classes
        const enrolledClasses = await prisma.pesertaKelas.findMany({
            where: {
                id_mahasiswa: id_user,
                deletedAt: null,
                kelas: { deletedAt: null }
            },
            select: { id_kelas: true }
        });

        if (enrolledClasses.length === 0) {
            return res.status(400).json({
                status: 'error',
                message: 'Anda tidak terdaftar di kelas manapun'
            });
        }

        const kelasIds = enrolledClasses.map(p => p.id_kelas);

        // Step 3: Find OPEN attendance session for enrolled classes
        const now = new Date();
        const activeSesi = await prisma.sesiAbsensi.findFirst({
            where: {
                id_kelas: { in: kelasIds },
                status: true,  // true = sesi masih terbuka
                mulai: { lte: now },
                selesai: { gte: now },
                deletedAt: null
            },
            include: {
                kelas: {
                    include: {
                        matakuliah: true,
                        dosen: { select: { id_user: true, nama: true } }
                    }
                }
            }
        });

        if (!activeSesi) {
            return res.status(400).json({
                status: 'error',
                message: 'Tidak ada sesi absensi yang sedang berlangsung untuk kelas Anda'
            });
        }

        // Step 4: Check if already marked attendance
        const existingAbsensi = await prisma.absensi.findFirst({
            where: {
                id_user,
                id_sesi_absensi: activeSesi.id_sesi_absensi,
                deletedAt: null
            }
        });

        if (existingAbsensi) {
            return res.status(409).json({
                status: 'error',
                message: 'Anda sudah melakukan absensi pada sesi ini',
                kelas: activeSesi.kelas.matakuliah?.nama_matakuliah || activeSesi.kelas.nama_kelas
            });
        }

        // Step 5: Check location (if session has location requirements)
        if (activeSesi.latitude !== null && activeSesi.longitude !== null && activeSesi.radius_meter !== null) {
            const distance = haversineDistance(activeSesi.latitude, activeSesi.longitude, lat, lng);
            if (distance > activeSesi.radius_meter) {
                return res.status(403).json({
                    status: 'error',
                    message: 'Lokasi Anda di luar area absensi',
                    distance: Math.round(distance),
                    required_radius: activeSesi.radius_meter
                });
            }
        }

        // Step 6: Create attendance record
        await prisma.$executeRaw`
            INSERT INTO absensi (id_user, id_kelas, id_sesi_absensi, type_absensi, koordinat, "updatedAt")
            VALUES (
                ${id_user},
                ${activeSesi.id_kelas},
                ${activeSesi.id_sesi_absensi},
                ${activeSesi.type_absensi}::"TypeAbsensi",
                POINT(${lng}, ${lat}),
                NOW()
            )
        `;

        const absensi = await prisma.absensi.findFirst({
            where: { id_user, id_sesi_absensi: activeSesi.id_sesi_absensi },
            orderBy: { createdAt: 'desc' },
            include: {
                kelas: { include: { matakuliah: true } },
                sesiAbsensi: true
            }
        });

        // Audit log for successful attendance
        logAudit({
            action: BIOMETRIK_ACTIONS.ABSEN_SUCCESS,
            performedBy: id_user,
            targetUserId: id_user,
            details: `Biometric attendance: kelas=${activeSesi.kelas.nama_kelas}, similarity=${matchResult.similarity}`,
            ip: req.ip
        });

        res.status(201).json({
            status: 'success',
            message: 'Absensi berhasil dicatat',
            data: {
                nama: userBiometric.user.nama,
                kelas: activeSesi.kelas.matakuliah?.nama_matakuliah || activeSesi.kelas.nama_kelas,
                ruangan: activeSesi.kelas.ruangan,
                waktu: absensi.createdAt,
                type: activeSesi.type_absensi,
                similarity: matchResult.similarity
            }
        });

    } catch (error) {
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        throw error;
    }
});
