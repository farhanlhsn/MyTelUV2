const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { uploadFile, deleteFile, fileExists } = require('../utils/r2FileHandler');
const { sendPushNotification } = require('../utils/firebase');
const { parsePagination, buildPaginationMeta } = require('../utils/paginationHelper');

exports.registerKendaraan = asyncHandler(async (req, res) => {
    const { plat_nomor, nama_kendaraan } = req.body;

    const id_user = req.user.id_user;

    // Ambil files dari req.files object
    const fotoKendaraanFiles = req.files.fotoKendaraan || [];
    const fotoSTNKFiles = req.files.fotoSTNK || [];
    const fotoSTNKFile = fotoSTNKFiles[0]; // Ambil file pertama

    // Validasi jumlah foto kendaraan (wajib 3 foto, max 5)
    if (!fotoKendaraanFiles || fotoKendaraanFiles.length < 3) {
        return res.status(400).json({
            status: "error",
            message: `Exactly 3 fotoKendaraan are required (you uploaded ${fotoKendaraanFiles.length})`
        });
    }

    // Validasi foto STNK wajib ada
    if (!fotoSTNKFile) {
        return res.status(400).json({
            status: "error",
            message: "fotoSTNK is required"
        });
    }

    // Cek apakah plat nomor sudah terdaftar
    const existingKendaraan = await prisma.kendaraan.findUnique({
        where: { plat_nomor }
    });

    if (existingKendaraan) {
        return res.status(409).json({
            status: "error",
            message: "Plat nomor already registered"
        });
    }

    // Cek batas maksimal kendaraan per user
    const maxKendaraan = parseInt(process.env.MAX_KENDARAAN_PER_USER) || 3;
    const userKendaraanCount = await prisma.kendaraan.count({
        where: { id_user, deletedAt: null }
    });

    if (userKendaraanCount >= maxKendaraan) {
        return res.status(400).json({
            status: "error",
            message: `User has reached the maximum limit of ${maxKendaraan} vehicles`
        });
    }

    // Upload semua foto kendaraan ke R2
    const uploadedFotoKendaraan = [];
    for (const file of fotoKendaraanFiles) {
        try {
            const result = await uploadFile(
                file.buffer,
                file.originalname,
                file.mimetype,
                'kendaraan'
            );
            uploadedFotoKendaraan.push(result.fileUrl);
        } catch (error) {
            return res.status(500).json({
                status: "error",
                message: `Failed to upload fotoKendaraan: ${error.message}`
            });
        }
    }

    // Upload foto STNK ke R2
    let uploadedFotoSTNK;
    try {
        const result = await uploadFile(
            fotoSTNKFile.buffer,
            fotoSTNKFile.originalname,
            fotoSTNKFile.mimetype,
            'stnk'
        );
        uploadedFotoSTNK = result.fileUrl;
    } catch (error) {
        return res.status(500).json({
            status: "error",
            message: `Failed to upload fotoSTNK: ${error.message}`
        });
    }

    // Simpan ke database
    try {
        const kendaraan = await prisma.kendaraan.create({
            data: {
                plat_nomor,
                nama_kendaraan,
                id_user: id_user, // Menggunakan id_user dari token (req.user)
                fotoKendaraan: uploadedFotoKendaraan,
                fotoSTNK: uploadedFotoSTNK,
                statusVerif: false,
                status_pengajuan: 'MENUNGGU'
            },
        });

        res.status(201).json({
            status: "success",
            message: "Kendaraan registered successfully",
            data: kendaraan
        });
    } catch (error) {
        // Cleanup uploaded files on database failure
        for (const fotoUrl of uploadedFotoKendaraan) {
            try {
                if (await fileExists(fotoUrl)) await deleteFile(fotoUrl);
            } catch (cleanupError) {
                console.error(`Failed to cleanup foto kendaraan: ${cleanupError.message}`);
            }
        }
        try {
            if (await fileExists(uploadedFotoSTNK)) await deleteFile(uploadedFotoSTNK);
        } catch (cleanupError) {
            console.error(`Failed to cleanup foto STNK: ${cleanupError.message}`);
        }

        return res.status(500).json({
            status: "error",
            message: `Failed to save kendaraan: ${error.message}`
        });
    }
});

exports.getKendaraan = asyncHandler(async (req, res) => {
    const kendaraan = await prisma.kendaraan.findMany({
        where: {
            id_user: req.user.id_user
        },
        select: {
            id_kendaraan: true,
            plat_nomor: true,
            nama_kendaraan: true,
            fotoKendaraan: true,
            fotoSTNK: true,
            statusVerif: true,
            status_pengajuan: true,
            feedback: true,
            createdAt: true,
            updatedAt: true
        },
        orderBy: {
            createdAt: 'desc'
        }
    });
    res.status(200).json({ status: "success", message: "Kendaraan retrieved successfully", data: kendaraan });
});

exports.deleteKendaraan = asyncHandler(async (req, res) => {
    const { id_kendaraan } = req.params;
    const kendaraan = await prisma.kendaraan.findUnique({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: req.user.id_user }
    });
    if (!kendaraan) {
        return res.status(404).json({ status: "error", message: "Kendaraan not found" });
    }
    // Delete foto kendaraan dan foto STNK from R2
    for (const foto of kendaraan.fotoKendaraan) {
        if (await fileExists(foto)) {
            await deleteFile(foto);
        }
    }
    if (await fileExists(kendaraan.fotoSTNK)) {
        await deleteFile(kendaraan.fotoSTNK);
    }
    // Delete kendaraan from database
    await prisma.kendaraan.delete({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: req.user.id_user }
    });
    res.status(200).json({ status: "success", message: `Kendaraan ${kendaraan.plat_nomor} deleted successfully` });
});

exports.verifyKendaraan = asyncHandler(async (req, res) => {
    const { id_kendaraan, id_user } = req.body;
    const kendaraan = await prisma.kendaraan.findUnique({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user) }
    });
    if (!kendaraan) {
        return res.status(404).json({ status: "error", message: "Kendaraan not found" });
    }

    if (kendaraan.statusVerif) {
        return res.status(400).json({ status: "error", message: "Kendaraan already verified" });
    }

    const updatedKendaraan = await prisma.kendaraan.update({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user) },
        data: {
            statusVerif: true,
            status_pengajuan: 'DISETUJUI'
        }
    });

    // Send push notification to user
    try {
        const user = await prisma.user.findUnique({
            where: { id_user: parseInt(id_user) },
            select: { fcm_token: true }
        });
        if (user?.fcm_token) {
            await sendPushNotification(
                user.fcm_token,
                '✅ Kendaraan Disetujui',
                `Kendaraan ${kendaraan.plat_nomor} (${kendaraan.nama_kendaraan}) telah disetujui!`,
                { type: 'KENDARAAN_APPROVED', id_kendaraan: id_kendaraan.toString() }
            );
        }
    } catch (notifError) {
        console.error('Failed to send notification:', notifError.message);
    }

    res.status(200).json({ status: "success", message: "Kendaraan verified successfully", data: updatedKendaraan });
});

exports.getAllUnverifiedKendaraan = asyncHandler(async (req, res) => {
    const { page, limit, skip } = parsePagination(req.query);
    const total = await prisma.kendaraan.count({ where: { statusVerif: false, deletedAt: null } });

    const unverifiedKendaraan = await prisma.kendaraan.findMany({
        where: { statusVerif: false },
        include: {
            user: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true
                }
            }
        },
        skip: skip,
        take: limit,
        orderBy: [
            { status_pengajuan: 'asc' }, // MENUNGGU comes before DITOLAK/DISETUJUI alphabetically
            { createdAt: 'desc' }
        ]
    });

    res.status(200).json({
        status: "success",
        message: "All unverified kendaraan retrieved successfully",
        data: unverifiedKendaraan,
        pagination: buildPaginationMeta(total, page, limit)
    });
});

exports.getAllKendaraan = asyncHandler(async (req, res) => {
    const { page, limit, skip } = parsePagination(req.query);
    const total = await prisma.kendaraan.count({ where: { deletedAt: null } });

    const kendaraan = await prisma.kendaraan.findMany({
        where: { deletedAt: null },
        skip: skip,
        take: limit,
        orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({
        status: "success",
        message: "All kendaraan retrieved successfully",
        data: kendaraan,
        pagination: buildPaginationMeta(total, page, limit)
    });
});

// Get histori pengajuan kendaraan untuk user
exports.getHistoriPengajuan = asyncHandler(async (req, res) => {
    const kendaraan = await prisma.kendaraan.findMany({
        where: {
            id_user: req.user.id_user
        },
        select: {
            id_kendaraan: true,
            plat_nomor: true,
            nama_kendaraan: true,
            status_pengajuan: true,
            feedback: true,
            fotoKendaraan: true,
            fotoSTNK: true,
            createdAt: true,
            updatedAt: true
        },
        orderBy: {
            createdAt: 'desc'
        }
    });

    res.status(200).json({
        status: "success",
        message: "Histori pengajuan retrieved successfully",
        data: kendaraan
    });
});

// Reject pengajuan kendaraan dengan feedback
exports.rejectKendaraan = asyncHandler(async (req, res) => {
    const { id_kendaraan, id_user, feedback } = req.body;

    if (!feedback || feedback.trim() === '') {
        return res.status(400).json({
            status: "error",
            message: "Feedback is required when rejecting"
        });
    }

    const kendaraan = await prisma.kendaraan.findUnique({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user) }
    });

    if (!kendaraan) {
        return res.status(404).json({
            status: "error",
            message: "Kendaraan not found"
        });
    }

    if (kendaraan.status_pengajuan === 'DISETUJUI') {
        return res.status(400).json({
            status: "error",
            message: "Cannot reject already approved kendaraan"
        });
    }

    const updatedKendaraan = await prisma.kendaraan.update({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user) },
        data: {
            statusVerif: false,
            status_pengajuan: 'DITOLAK',
            feedback: feedback
        }
    });

    // Send push notification to user about rejection
    try {
        const user = await prisma.user.findUnique({
            where: { id_user: parseInt(id_user) },
            select: { fcm_token: true }
        });
        if (user?.fcm_token) {
            await sendPushNotification(
                user.fcm_token,
                '❌ Kendaraan Ditolak',
                `Kendaraan ${kendaraan.plat_nomor} ditolak. Alasan: ${feedback}`,
                { type: 'KENDARAAN_REJECTED', id_kendaraan: id_kendaraan.toString(), feedback: feedback }
            );
        }
    } catch (notifError) {
        console.error('Failed to send notification:', notifError.message);
    }

    res.status(200).json({
        status: "success",
        message: "Kendaraan rejected successfully",
        data: updatedKendaraan
    });
});

exports.resubmitKendaraan = asyncHandler(async (req, res) => {
    const { id_kendaraan } = req.params;
    const id_user = req.user.id_user;
    
    const kendaraan = await prisma.kendaraan.findUnique({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user, deletedAt: null }
    });

    if (!kendaraan) {
        return res.status(404).json({ status: "error", message: "Kendaraan not found" });
    }

    if (kendaraan.status_pengajuan !== 'DITOLAK') {
        return res.status(400).json({ status: "error", message: "Only rejected vehicles can be resubmitted" });
    }

    const fotoKendaraanFiles = req.files?.fotoKendaraan || [];
    const fotoSTNKFiles = req.files?.fotoSTNK || [];
    const fotoSTNKFile = fotoSTNKFiles[0];

    const dataToUpdate = {
        status_pengajuan: 'MENUNGGU',
        statusVerif: false,
        feedback: null
    };

    if (fotoKendaraanFiles.length > 0) {
        if (fotoKendaraanFiles.length < 3) {
            return res.status(400).json({ status: "error", message: "If updating vehicle photos, you must provide exactly 3 photos" });
        }
        
        const uploadedFotoKendaraan = [];
        for (const file of fotoKendaraanFiles) {
            const result = await uploadFile(file.buffer, file.originalname, file.mimetype, 'kendaraan');
            uploadedFotoKendaraan.push(result.fileUrl);
        }
        dataToUpdate.fotoKendaraan = uploadedFotoKendaraan;
        
        // Delete old photos (async, non-blocking)
        kendaraan.fotoKendaraan.forEach(url => deleteFile(url).catch(e => console.error(e)));
    }

    if (fotoSTNKFile) {
        const result = await uploadFile(fotoSTNKFile.buffer, fotoSTNKFile.originalname, fotoSTNKFile.mimetype, 'stnk');
        dataToUpdate.fotoSTNK = result.fileUrl;
        
        // Delete old stnk
        deleteFile(kendaraan.fotoSTNK).catch(e => console.error(e));
    }

    const updatedKendaraan = await prisma.kendaraan.update({
        where: { id_kendaraan: parseInt(id_kendaraan) },
        data: dataToUpdate
    });

    res.status(200).json({
        status: "success",
        message: "Kendaraan resubmitted successfully",
        data: updatedKendaraan
    });
});