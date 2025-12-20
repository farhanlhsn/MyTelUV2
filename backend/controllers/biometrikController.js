const prisma = require('../utils/prisma');
const asyncHandler = require('express-async-handler');
const FormData = require('form-data');
const axios = require('axios');
const fs = require('fs');
const { uploadFile, deleteFile } = require('../utils/r2FileHandler');

const PYTHON_SERVICE_URL = process.env.PYTHON_SERVICE_URL || 'http://localhost:5051';
const SIMILARITY_THRESHOLD = parseFloat(process.env.FACE_SIMILARITY_THRESHOLD || '0.6');

/**
 * Helper function to call Python service
 */
const callPythonService = async (endpoint, formData) => {
    try {
        const response = await axios.post(`${PYTHON_SERVICE_URL}${endpoint}`, formData, {
            headers: formData.getHeaders ? formData.getHeaders() : { 'Content-Type': 'application/json' },
            maxContentLength: Infinity,
            maxBodyLength: Infinity
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

        // Get all active biometric data
        const allBiometrics = await prisma.dataBiometrik.findMany({
            where: {
                deletedAt: null
            },
            include: {
                user: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true,
                        role: true
                    }
                }
            }
        });

        if (allBiometrics.length === 0) {
            return res.status(200).json({
                status: 'success',
                matched: false,
                message: 'No registered faces in database'
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

        // Get all active biometric data
        const allBiometrics = await prisma.dataBiometrik.findMany({
            where: {
                deletedAt: null
            },
            include: {
                user: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true,
                        role: true
                    }
                }
            }
        });

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

        // Match each detected face
        const identifiedUsers = [];
        const embeddings_list = allBiometrics.map(b => b.face_embedding);

        for (const face of facesResult.faces) {
            const matchResult = await callPythonService('/find-match', {
                target_embedding: face.embedding,
                embeddings_list: embeddings_list
            });

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
