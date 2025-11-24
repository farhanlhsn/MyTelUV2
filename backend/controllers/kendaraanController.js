const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { uploadFile, deleteFile, fileExists } = require('../utils/r2FileHandler');

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
    res.status(200).json({ status: "success", message: "Kendaraan verified successfully", data: updatedKendaraan });
});

exports.getAllUnverifiedKendaraan = asyncHandler(async (req, res) => {
    const { page = 1, limit = 10 } = req.params;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const total = await prisma.kendaraan.count({ where: { statusVerif: false } });
    const totalPages = Math.ceil(total / limit);
    const unverifiedKendaraan = await prisma.kendaraan.findMany({
        where: { statusVerif: false },
        skip: offset,
        take: parseInt(limit)
    });
    res.status(200).json({ status: "success", message: "All unverified kendaraan retrieved successfully", data: unverifiedKendaraan, totalPages: totalPages, total: total });
});

exports.getAllKendaraan = asyncHandler(async (req, res) => {
    const { page = 1, limit = 10 } = req.params;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const total = await prisma.kendaraan.count();
    const totalPages = Math.ceil(total / limit);
    const kendaraan = await prisma.kendaraan.findMany({
        skip: offset,
        take: parseInt(limit)
    });
    res.status(200).json({ status: "success", message: "All unverified kendaraan retrieved successfully", data: kendaraan, totalPages: totalPages, total: total });
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
    
    res.status(200).json({ 
        status: "success", 
        message: "Kendaraan rejected successfully", 
        data: updatedKendaraan 
    });
});

//kayaknya ga butuh
exports.getAllMyKendaraan = asyncHandler(async (req, res) => {
    const kendaraan = await prisma.kendaraan.findMany({
        where: {
            id_user: req.user.id_user
        }
    });
    res.status(200).json({ status: "success", message: "All my kendaraan retrieved successfully", data: kendaraan });
});