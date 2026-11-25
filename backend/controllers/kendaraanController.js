const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { uploadFile, deleteFile, fileExists } = require('../utils/r2FileHandler');
const { sendUserNotification } = require('../utils/firebase');
const { parsePagination, buildPaginationMeta } = require('../utils/paginationHelper');
const { GENERIC_SERVER_ERROR } = require('../utils/serverError');
const { normalizePlate } = require('../utils/plate');

// Best effort: removing superseded files from R2 must never fail (or delay) the request.
const discardFiles = (urls) => {
    for (const url of urls.filter(Boolean)) {
        (async () => {
            try {
                await deleteFile(url);
            } catch (error) {
                console.error(`Failed to delete superseded file: ${error.message}`);
            }
        })();
    }
};

exports.registerKendaraan = asyncHandler(async (req, res) => {
    const { nama_kendaraan } = req.body;
    // The Zod schema already normalises the plate; do it here as well so uniqueness is always checked on one canonical form
    const plat_nomor = normalizePlate(req.body.plat_nomor);

    const id_user = req.user.id_user;

    if (!plat_nomor) {
        return res.status(400).json({
            status: "error",
            message: "Plat nomor tidak valid"
        });
    }

    // Ambil files dari req.files object
    const fotoKendaraanFiles = req.files.fotoKendaraan || [];
    const fotoSTNKFiles = req.files.fotoSTNK || [];
    const fotoSTNKFile = fotoSTNKFiles[0]; // Ambil file pertama

    // Validasi jumlah foto kendaraan (wajib 3 foto, max 5)
    if (!fotoKendaraanFiles || fotoKendaraanFiles.length < 3) {
        return res.status(400).json({
            status: "error",
            message: `Wajib melampirkan tepat 3 foto kendaraan (Anda mengunggah ${fotoKendaraanFiles.length})`
        });
    }

    // Validasi foto STNK wajib ada
    if (!fotoSTNKFile) {
        return res.status(400).json({
            status: "error",
            message: "Foto STNK wajib dilampirkan"
        });
    }

    // Cek apakah plat nomor sudah terdaftar
    const existingKendaraan = await prisma.kendaraan.findUnique({
        where: { plat_nomor }
    });

    if (existingKendaraan && !existingKendaraan.deletedAt) {
        return res.status(409).json({
            status: "error",
            message: "Plat nomor sudah terdaftar"
        });
    }

    // plat_nomor is unique at the database level, so a plate whose row was soft-deleted can only be re-registered by
    // reusing that row (see the save step below)
    const reusableKendaraan = existingKendaraan || null;

    // Cek batas maksimal kendaraan per user (kecuali yang ditolak/rejected)
    const maxKendaraan = parseInt(process.env.MAX_KENDARAAN_PER_USER) || 3;
    const userKendaraanCount = await prisma.kendaraan.count({
        where: { 
            id_user, 
            deletedAt: null,
            status_pengajuan: {
                not: 'DITOLAK'
            }
        }
    });

    if (userKendaraanCount >= maxKendaraan) {
        return res.status(400).json({
            status: "error",
            message: `Pengguna sudah mencapai batas maksimal ${maxKendaraan} kendaraan`
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
            console.error('Failed to upload fotoKendaraan:', error.message);
            return res.status(500).json({
                status: "error",
                message: GENERIC_SERVER_ERROR
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
        console.error('Failed to upload fotoSTNK:', error.message);
        return res.status(500).json({
            status: "error",
            message: GENERIC_SERVER_ERROR
        });
    }

    // Simpan ke database
    let kendaraan;
    try {
        if (reusableKendaraan) {
            // Reuse the soft-deleted row: new owner, back to MENUNGGU, no feedback. The deletedAt filter makes a
            // concurrent second registration of the same plate fail (P2025) instead of taking the row over twice.
            kendaraan = await prisma.kendaraan.update({
                where: { id_kendaraan: reusableKendaraan.id_kendaraan, deletedAt: { not: null } },
                data: {
                    id_user, // Menggunakan id_user dari token (req.user)
                    nama_kendaraan,
                    fotoKendaraan: uploadedFotoKendaraan,
                    fotoSTNK: uploadedFotoSTNK,
                    statusVerif: false,
                    status_pengajuan: 'MENUNGGU',
                    feedback: null,
                    deletedAt: null,
                    createdAt: new Date() // the admin pending queue is ordered by createdAt, newest first
                }
            });
        } else {
            kendaraan = await prisma.kendaraan.create({
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
        }
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

        // Lost a race for the same plate (unique violation, or the soft-deleted row was reused first)
        if (error.code === 'P2002' || error.code === 'P2025') {
            return res.status(409).json({
                status: "error",
                message: "Plat nomor sudah terdaftar"
            });
        }

        console.error('Failed to save kendaraan:', error.message);
        return res.status(500).json({
            status: "error",
            message: GENERIC_SERVER_ERROR
        });
    }

    if (reusableKendaraan) {
        discardFiles([...(reusableKendaraan.fotoKendaraan || []), reusableKendaraan.fotoSTNK]);
    }

    res.status(201).json({
        status: "success",
        message: "Kendaraan berhasil didaftarkan",
        data: kendaraan
    });
});

exports.getKendaraan = asyncHandler(async (req, res) => {
    const kendaraan = await prisma.kendaraan.findMany({
        where: {
            id_user: req.user.id_user,
            deletedAt: null
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
    res.status(200).json({ status: "success", message: "Data kendaraan berhasil diambil", data: kendaraan });
});

exports.deleteKendaraan = asyncHandler(async (req, res) => {
    const { id_kendaraan } = req.params;
    const { reason } = req.body;
    const id_user = req.user.id_user;

    const kendaraan = await prisma.kendaraan.findUnique({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user, deletedAt: null }
    });
    if (!kendaraan || kendaraan.deletedAt) {
        return res.status(404).json({ status: "error", message: "Kendaraan tidak ditemukan" });
    }

    // Hanya kendaraan yang sudah disetujui yang bisa diajukan hapus. Ini menjamin bahwa menolak permintaan hapus
    // (rejectKendaraan) selalu mengembalikan kendaraan ke keadaan DISETUJUI yang benar.
    if (kendaraan.status_pengajuan !== 'DISETUJUI') {
        return res.status(409).json({
            status: "error",
            message: "Hanya kendaraan yang sudah disetujui yang bisa diajukan hapus"
        });
    }

    // Set status to MENUNGGU dengan format feedback khusus untuk permintaan penghapusan
    await prisma.kendaraan.update({
        where: { id_kendaraan: parseInt(id_kendaraan) },
        data: {
            status_pengajuan: 'MENUNGGU',
            statusVerif: false,
            feedback: `DELETE_REQUEST: ${reason || 'No reason provided'}`
        }
    });

    res.status(200).json({ status: "success", message: "Permintaan penghapusan kendaraan berhasil diajukan" });
});

exports.verifyKendaraan = asyncHandler(async (req, res) => {
    const { id_kendaraan, id_user } = req.body;
    const kendaraan = await prisma.kendaraan.findUnique({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user), deletedAt: null }
    });
    if (!kendaraan) {
        return res.status(404).json({ status: "error", message: "Kendaraan tidak ditemukan" });
    }

    if (kendaraan.statusVerif) {
        return res.status(400).json({ status: "error", message: "Kendaraan sudah diverifikasi" });
    }

    // Jika ini adalah permintaan hapus kendaraan
    if (kendaraan.feedback && kendaraan.feedback.startsWith('DELETE_REQUEST:')) {
        const updatedKendaraan = await prisma.kendaraan.update({
            where: { id_kendaraan: parseInt(id_kendaraan) },
            data: {
                deletedAt: new Date(),
                statusVerif: false
            }
        });

        // Kirim notifikasi penghapusan disetujui ke user
        try {
            // Skipped by the helper when the user turned push off or the account is deactivated
            await sendUserNotification(
                parseInt(id_user),
                '🗑️ Kendaraan Dihapus',
                `Permintaan penghapusan kendaraan ${kendaraan.plat_nomor} telah disetujui admin.`,
                { type: 'KENDARAAN_DELETED', id_kendaraan: id_kendaraan.toString() }
            );
        } catch (notifError) {
            console.error('Failed to send notification:', notifError.message);
        }

        return res.status(200).json({ status: "success", message: "Penghapusan kendaraan disetujui dan kendaraan berhasil dihapus", data: updatedKendaraan });
    }

    const updatedKendaraan = await prisma.kendaraan.update({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user) },
        data: {
            statusVerif: true,
            status_pengajuan: 'DISETUJUI',
            feedback: null
        }
    });

    // Send push notification to user
    try {
        // Skipped by the helper when the user turned push off or the account is deactivated
        await sendUserNotification(
            parseInt(id_user),
            '✅ Kendaraan Disetujui',
            `Kendaraan ${kendaraan.plat_nomor} (${kendaraan.nama_kendaraan}) telah disetujui!`,
            { type: 'KENDARAAN_APPROVED', id_kendaraan: id_kendaraan.toString() }
        );
    } catch (notifError) {
        console.error('Failed to send notification:', notifError.message);
    }

    res.status(200).json({ status: "success", message: "Kendaraan berhasil diverifikasi", data: updatedKendaraan });
});

exports.getAllUnverifiedKendaraan = asyncHandler(async (req, res) => {
    const { page, limit, skip } = parsePagination(req.query);
    const { search, status } = req.query;

    const whereClause = {
        statusVerif: false,
        deletedAt: null
    };

    if (status) {
        whereClause.status_pengajuan = status;
    }

    if (search) {
        // Plates are stored normalised, so match the normalised term (and the raw one, for rows saved before that)
        const plateTerms = [...new Set([normalizePlate(search), search].filter(Boolean))];
        whereClause.OR = [
            ...plateTerms.map((term) => ({ plat_nomor: { contains: term, mode: 'insensitive' } })),
            { nama_kendaraan: { contains: search, mode: 'insensitive' } },
            {
                user: {
                    OR: [
                        { nama: { contains: search, mode: 'insensitive' } },
                        { username: { contains: search, mode: 'insensitive' } }
                    ]
                }
            }
        ];
    }

    const total = await prisma.kendaraan.count({ where: whereClause });

    const unverifiedKendaraan = await prisma.kendaraan.findMany({
        where: whereClause,
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
        message: "Semua kendaraan yang belum diverifikasi berhasil diambil",
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
        message: "Semua data kendaraan berhasil diambil",
        data: kendaraan,
        pagination: buildPaginationMeta(total, page, limit)
    });
});

// Get histori pengajuan kendaraan untuk user
exports.getHistoriPengajuan = asyncHandler(async (req, res) => {
    const kendaraan = await prisma.kendaraan.findMany({
        where: {
            id_user: req.user.id_user,
            deletedAt: null
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
        message: "Riwayat pengajuan berhasil diambil",
        data: kendaraan
    });
});

// Reject pengajuan kendaraan dengan feedback
exports.rejectKendaraan = asyncHandler(async (req, res) => {
    const { id_kendaraan, id_user, feedback } = req.body;

    if (!feedback || feedback.trim() === '') {
        return res.status(400).json({
            status: "error",
            message: "Alasan penolakan wajib diisi"
        });
    }

    const kendaraan = await prisma.kendaraan.findUnique({
        where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user), deletedAt: null }
    });

    if (!kendaraan) {
        return res.status(404).json({
            status: "error",
            message: "Kendaraan tidak ditemukan"
        });
    }

    // Jika ini adalah penolakan permintaan hapus kendaraan.
    // deleteKendaraan hanya menerima permintaan dari kendaraan DISETUJUI (statusVerif true), jadi mengembalikan
    // DISETUJUI + statusVerif true di sini selalu memulihkan keadaan sebelum permintaan diajukan.
    if (kendaraan.feedback && kendaraan.feedback.startsWith('DELETE_REQUEST:')) {
        const updatedKendaraan = await prisma.kendaraan.update({
            where: { id_kendaraan: parseInt(id_kendaraan), id_user: parseInt(id_user) },
            data: {
                status_pengajuan: 'DISETUJUI',
                statusVerif: true,
                feedback: `PENOLAKAN_HAPUS: ${feedback || 'Ditolak oleh admin'}`
            }
        });

        // Kirim notifikasi penolakan penghapusan ke user
        try {
            // Skipped by the helper when the user turned push off or the account is deactivated
            await sendUserNotification(
                parseInt(id_user),
                '❌ Pembatalan Penghapusan Kendaraan',
                `Permintaan penghapusan kendaraan ${kendaraan.plat_nomor} ditolak admin. Alasan: ${feedback}`,
                { type: 'KENDARAAN_DELETE_REJECTED', id_kendaraan: id_kendaraan.toString() }
            );
        } catch (notifError) {
            console.error('Failed to send notification:', notifError.message);
        }

        return res.status(200).json({ status: "success", message: "Permintaan penghapusan kendaraan ditolak", data: updatedKendaraan });
    }

    if (kendaraan.status_pengajuan === 'DISETUJUI') {
        return res.status(400).json({
            status: "error",
            message: "Kendaraan yang sudah disetujui tidak dapat ditolak"
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
        // Skipped by the helper when the user turned push off or the account is deactivated
        await sendUserNotification(
            parseInt(id_user),
            '❌ Kendaraan Ditolak',
            `Kendaraan ${kendaraan.plat_nomor} ditolak. Alasan: ${feedback}`,
            { type: 'KENDARAAN_REJECTED', id_kendaraan: id_kendaraan.toString(), feedback: feedback }
        );
    } catch (notifError) {
        console.error('Failed to send notification:', notifError.message);
    }

    res.status(200).json({
        status: "success",
        message: "Kendaraan berhasil ditolak",
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
        return res.status(404).json({ status: "error", message: "Kendaraan tidak ditemukan" });
    }

    if (kendaraan.status_pengajuan !== 'DITOLAK') {
        return res.status(400).json({ status: "error", message: "Hanya kendaraan yang ditolak yang dapat diajukan ulang" });
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
            return res.status(400).json({ status: "error", message: "Jika mengubah foto kendaraan, lampirkan tepat 3 foto" });
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
        message: "Kendaraan berhasil diajukan ulang",
        data: updatedKendaraan
    });
});