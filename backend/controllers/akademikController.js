const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');

// ==================== MATAKULIAH CONTROLLERS ====================
exports.createMatakuliah = asyncHandler(async (req, res) => {
    const { nama_matakuliah, kode_matakuliah } = req.body;
    
    // Check if kode already exists
    const existingMatakuliah = await prisma.matakuliah.findFirst({
        where: { 
            kode_matakuliah,
            deletedAt: null 
        }
    });
    
    if (existingMatakuliah) {
        return res.status(409).json({ 
            status: "error", 
            message: "Kode matakuliah already exists" 
        });
    }
    
    const matakuliah = await prisma.matakuliah.create({
        data: { 
            nama_matakuliah: nama_matakuliah.trim(), 
            kode_matakuliah: kode_matakuliah.trim().toUpperCase() 
        }
    });
    
    res.status(201).json({ 
        status: "success", 
        message: "Matakuliah created successfully",
        data: matakuliah
    });
});

exports.getAllMatakuliah = asyncHandler(async (req, res) => {
    const { search, page = 1, limit = 10 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const where = { deletedAt: null };
    
    // Search by nama or kode
    if (search) {
        where.OR = [
            { nama_matakuliah: { contains: search, mode: 'insensitive' } },
            { kode_matakuliah: { contains: search, mode: 'insensitive' } }
        ];
    }
    
    const [matakuliah, total] = await prisma.$transaction([
        prisma.matakuliah.findMany({
            where,
            skip,
            take: parseInt(limit),
            include: {
                kelas: {
                    where: { deletedAt: null },
                    select: {
                        id_kelas: true,
                        nama_kelas: true,
                        ruangan: true
                    }
                }
            },
            orderBy: { kode_matakuliah: 'asc' }
        }),
        prisma.matakuliah.count({ where })
    ]);
    
    res.status(200).json({ 
        status: "success", 
        data: matakuliah,
        pagination: {
            total,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(total / parseInt(limit))
        }
    });
});

exports.getMatakuliahById = asyncHandler(async (req, res) => {
    const { id } = req.params;
    
    const matakuliah = await prisma.matakuliah.findFirst({
        where: { 
            id_matakuliah: parseInt(id),
            deletedAt: null 
        },
        include: {
            kelas: {
                where: { deletedAt: null },
                include: {
                    dosen: {
                        select: {
                            id_user: true,
                            nama: true,
                            username: true
                        }
                    }
                }
            }
        }
    });
    
    if (!matakuliah) {
        return res.status(404).json({ 
            status: "error", 
            message: "Matakuliah not found" 
        });
    }
    
    res.status(200).json({ 
        status: "success", 
        data: matakuliah 
    });
});

exports.updateMatakuliah = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { nama_matakuliah, kode_matakuliah } = req.body;
    
    const matakuliah = await prisma.matakuliah.findFirst({
        where: { 
            id_matakuliah: parseInt(id),
            deletedAt: null 
        }
    });
    
    if (!matakuliah) {
        return res.status(404).json({ 
            status: "error", 
            message: "Matakuliah not found" 
        });
    }
    
    // Check if new kode already exists (excluding current)
    if (kode_matakuliah && kode_matakuliah !== matakuliah.kode_matakuliah) {
        const existingKode = await prisma.matakuliah.findFirst({
            where: { 
                kode_matakuliah: kode_matakuliah.trim().toUpperCase(),
                deletedAt: null,
                NOT: { id_matakuliah: parseInt(id) }
            }
        });
        
        if (existingKode) {
            return res.status(409).json({ 
                status: "error", 
                message: "Kode matakuliah already exists" 
            });
        }
    }
    
    const updatedMatakuliah = await prisma.matakuliah.update({
        where: { id_matakuliah: parseInt(id) },
        data: {
            ...(nama_matakuliah && { nama_matakuliah: nama_matakuliah.trim() }),
            ...(kode_matakuliah && { kode_matakuliah: kode_matakuliah.trim().toUpperCase() })
        }
    });
    
    res.status(200).json({ 
        status: "success", 
        message: "Matakuliah updated successfully",
        data: updatedMatakuliah 
    });
});

exports.deleteMatakuliah = asyncHandler(async (req, res) => {
    const { id } = req.params;
    
    const matakuliah = await prisma.matakuliah.findFirst({
        where: { 
            id_matakuliah: parseInt(id),
            deletedAt: null 
        },
        include: {
            kelas: {
                where: { deletedAt: null }
            }
        }
    });
    
    if (!matakuliah) {
        return res.status(404).json({ 
            status: "error", 
            message: "Matakuliah not found" 
        });
    }
    
    // Check if has active kelas
    if (matakuliah.kelas.length > 0) {
        return res.status(400).json({ 
            status: "error", 
            message: "Cannot delete matakuliah with active kelas. Delete or archive the kelas first." 
        });
    }
    
    await prisma.matakuliah.update({
        where: { id_matakuliah: parseInt(id) },
        data: { deletedAt: new Date() }
    });
    
    res.status(200).json({ 
        status: "success", 
        message: "Matakuliah deleted successfully" 
    });
});

// ==================== KELAS CONTROLLERS ====================

exports.createKelas = asyncHandler(async (req, res) => {
    const { id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan } = req.body;
    
    // Validate matakuliah exists
    const matakuliah = await prisma.matakuliah.findFirst({
        where: { 
            id_matakuliah: parseInt(id_matakuliah),
            deletedAt: null
        }
    });
    
    if (!matakuliah) {
        return res.status(404).json({ 
            status: "error", 
            message: "Matakuliah not found" 
        });
    }
    
    // Validate dosen exists and has DOSEN role
    const dosen = await prisma.user.findFirst({
        where: { 
            id_user: parseInt(id_dosen),
            role: 'DOSEN',
            deletedAt: null
        }
    });
    
    if (!dosen) {
        return res.status(404).json({ 
            status: "error", 
            message: "Dosen not found or invalid role" 
        });
    }
    
    // If user is DOSEN (not ADMIN), they can only create class for themselves
    if (req.user.role === 'DOSEN' && req.user.id_user !== parseInt(id_dosen)) {
        return res.status(403).json({ 
            status: "error", 
            message: "Dosen can only create classes for themselves" 
        });
    }
    
    // Validate time format (HH:MM:SS)
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/;
    if (!timeRegex.test(jam_mulai) || !timeRegex.test(jam_berakhir)) {
        return res.status(400).json({ 
            status: "error", 
            message: "Invalid time format. Use HH:MM:SS format (e.g., 08:00:00)" 
        });
    }
    
    // Check for schedule conflicts (same dosen, same time, same day)
    const conflictingKelas = await prisma.$queryRaw`
        SELECT * FROM kelas 
        WHERE id_dosen = ${parseInt(id_dosen)}
        AND deleted_at IS NULL
        AND (
            (jam_mulai <= ${jam_mulai}::time AND jam_berakhir > ${jam_mulai}::time)
            OR (jam_mulai < ${jam_berakhir}::time AND jam_berakhir >= ${jam_berakhir}::time)
            OR (jam_mulai >= ${jam_mulai}::time AND jam_berakhir <= ${jam_berakhir}::time)
        )
    `;
    
    if (conflictingKelas.length > 0) {
        return res.status(409).json({ 
            status: "error", 
            message: "Schedule conflict detected. Dosen already has a class at this time." 
        });
    }
    
    const kelas = await prisma.$executeRaw`
        INSERT INTO kelas (id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan, "createdAt", "updatedAt")
        VALUES (
            ${parseInt(id_matakuliah)}, 
            ${parseInt(id_dosen)}, 
            ${jam_mulai}::time, 
            ${jam_berakhir}::time, 
            ${nama_kelas.trim()}, 
            ${ruangan.trim()},
            NOW(),
            NOW()
        )
        RETURNING *
    `;
    
    // Fetch the created kelas with relations
    const createdKelas = await prisma.kelas.findFirst({
        orderBy: { createdAt: 'desc' },
        include: {
            matakuliah: true,
            dosen: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true
                }
            }
        }
    });
    
    res.status(201).json({ 
        status: "success", 
        message: "Kelas created successfully",
        data: createdKelas
    });
});

exports.getAllKelas = asyncHandler(async (req, res) => {
    const { id_matakuliah, id_dosen, ruangan, page = 1, limit = 10 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const where = { deletedAt: null };
    
    if (id_matakuliah) where.id_matakuliah = parseInt(id_matakuliah);
    if (id_dosen) where.id_dosen = parseInt(id_dosen);
    if (ruangan) where.ruangan = { contains: ruangan, mode: 'insensitive' };
    
    const [kelas, total] = await prisma.$transaction([
        prisma.kelas.findMany({
            where,
            skip,
            take: parseInt(limit),
            include: {
                matakuliah: true,
                dosen: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true
                    }
                },
                _count: {
                    select: {
                        peserta: {
                            where: { deletedAt: null }
                        }
                    }
                }
            },
            orderBy: { createdAt: 'desc' }
        }),
        prisma.kelas.count({ where })
    ]);
    
    res.status(200).json({ 
        status: "success", 
        data: kelas,
        pagination: {
            total,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(total / parseInt(limit))
        }
    });
});

exports.getKelasByDosen = asyncHandler(async (req, res) => {
    const id_dosen = req.user.id_user;
    
    const kelas = await prisma.kelas.findMany({
        where: { 
            id_dosen,
            deletedAt: null
        },
        include: {
            matakuliah: true,
            peserta: {
                where: { deletedAt: null },
                include: {
                    mahasiswa: {
                        select: {
                            id_user: true,
                            nama: true,
                            username: true
                        }
                    }
                }
            },
            _count: {
                select: {
                    peserta: {
                        where: { deletedAt: null }
                    }
                }
            }
        },
        orderBy: { createdAt: 'desc' }
    });
    
    res.status(200).json({ 
        status: "success", 
        data: kelas 
    });
});

exports.getKelasById = asyncHandler(async (req, res) => {
    const { id } = req.params;
    
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id),
            deletedAt: null 
        },
        include: {
            matakuliah: true,
            dosen: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true
                }
            },
            peserta: {
                where: { deletedAt: null },
                include: {
                    mahasiswa: {
                        select: {
                            id_user: true,
                            nama: true,
                            username: true
                        }
                    }
                }
            }
        }
    });
    
    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }
    
    res.status(200).json({ 
        status: "success", 
        data: kelas 
    });
});

exports.updateKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan } = req.body;
    
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id),
            deletedAt: null 
        }
    });
    
    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }
    
    // If user is DOSEN, they can only update their own class
    if (req.user.role === 'DOSEN' && req.user.id_user !== kelas.id_dosen) {
        return res.status(403).json({ 
            status: "error", 
            message: "You can only update your own classes" 
        });
    }
    
    // Validate matakuliah if provided
    if (id_matakuliah) {
        const matakuliah = await prisma.matakuliah.findFirst({
            where: { 
                id_matakuliah: parseInt(id_matakuliah),
                deletedAt: null
            }
        });
        
        if (!matakuliah) {
            return res.status(404).json({ 
                status: "error", 
                message: "Matakuliah not found" 
            });
        }
    }
    
    // Validate dosen if provided
    if (id_dosen) {
        const dosen = await prisma.user.findFirst({
            where: { 
                id_user: parseInt(id_dosen),
                role: 'DOSEN',
                deletedAt: null
            }
        });
        
        if (!dosen) {
            return res.status(404).json({ 
                status: "error", 
                message: "Dosen not found or invalid role" 
            });
        }
    }
    
    // Validate time format if provided
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/;
    if ((jam_mulai && !timeRegex.test(jam_mulai)) || (jam_berakhir && !timeRegex.test(jam_berakhir))) {
        return res.status(400).json({ 
            status: "error", 
            message: "Invalid time format. Use HH:MM:SS format (e.g., 08:00:00)" 
        });
    }
    
    // Build update data
    const updateData = {};
    if (id_matakuliah) updateData.id_matakuliah = parseInt(id_matakuliah);
    if (id_dosen) updateData.id_dosen = parseInt(id_dosen);
    if (nama_kelas) updateData.nama_kelas = nama_kelas.trim();
    if (ruangan) updateData.ruangan = ruangan.trim();
    
    // Handle time fields separately with raw query if provided
    if (jam_mulai || jam_berakhir) {
        const timeUpdateQuery = `
            UPDATE kelas 
            SET 
                ${jam_mulai ? `jam_mulai = '${jam_mulai}'::time,` : ''}
                ${jam_berakhir ? `jam_berakhir = '${jam_berakhir}'::time,` : ''}
                updated_at = NOW()
            WHERE id_kelas = ${parseInt(id)}
        `;
        
        await prisma.$executeRawUnsafe(timeUpdateQuery);
    }
    
    // Update other fields
    if (Object.keys(updateData).length > 0) {
        await prisma.kelas.update({
            where: { id_kelas: parseInt(id) },
            data: updateData
        });
    }
    
    // Fetch updated kelas
    const updatedKelas = await prisma.kelas.findFirst({
        where: { id_kelas: parseInt(id) },
        include: {
            matakuliah: true,
            dosen: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true
                }
            }
        }
    });
    
    res.status(200).json({ 
        status: "success", 
        message: "Kelas updated successfully",
        data: updatedKelas 
    });
});

exports.deleteKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id),
            deletedAt: null 
        }
    });
    
    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }
    
    // If user is DOSEN, they can only delete their own class
    if (req.user.role === 'DOSEN' && req.user.id_user !== kelas.id_dosen) {
        return res.status(403).json({ 
            status: "error", 
            message: "You can only delete your own classes" 
        });
    }
    
    // Soft delete kelas and all its peserta
    await prisma.$transaction([
        prisma.kelas.update({
            where: { id_kelas: parseInt(id) },
            data: { deletedAt: new Date() }
        }),
        prisma.pesertaKelas.updateMany({
            where: { 
                id_kelas: parseInt(id),
                deletedAt: null
            },
            data: { deletedAt: new Date() }
        })
    ]);
    
    res.status(200).json({ 
        status: "success", 
        message: "Kelas deleted successfully" 
    });
});

// ==================== PESERTA KELAS CONTROLLERS ====================

exports.daftarKelas = asyncHandler(async (req, res) => {
    const { id_kelas } = req.body;
    const id_mahasiswa = req.user.id_user;
    
    // Validate kelas exists
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id_kelas),
            deletedAt: null
        },
        include: {
            matakuliah: true
        }
    });
    
    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }
    
    // Check if already enrolled
    const existingPeserta = await prisma.pesertaKelas.findUnique({
        where: { 
            id_mahasiswa_id_kelas: {
                id_mahasiswa,
                id_kelas: parseInt(id_kelas)
            }
        }
    });
    
    // If already enrolled and not deleted
    if (existingPeserta && !existingPeserta.deletedAt) {
        return res.status(409).json({ 
            status: "error", 
            message: "Already enrolled in this class" 
        });
    }
    
    // If previously dropped, restore
    if (existingPeserta && existingPeserta.deletedAt) {
        const restored = await prisma.pesertaKelas.update({
            where: {
                id_mahasiswa_id_kelas: {
                    id_mahasiswa,
                    id_kelas: parseInt(id_kelas)
                }
            },
            data: { deletedAt: null },
        });
        
        // Fetch with relations
        const pesertaWithRelations = await prisma.pesertaKelas.findUnique({
            where: {
                id_mahasiswa_id_kelas: {
                    id_mahasiswa,
                    id_kelas: parseInt(id_kelas)
                }
            },
            include: {
                kelas: {
                    include: {
                        matakuliah: true,
                        dosen: {
                            select: {
                                id_user: true,
                                nama: true
                            }
                        }
                    }
                }
            }
        });
        
        return res.status(200).json({ 
            status: "success", 
            message: "Re-enrolled in class successfully",
            data: pesertaWithRelations
        });
    }
    
    // Create new enrollment
    const peserta = await prisma.pesertaKelas.create({
        data: {
            id_mahasiswa,
            id_kelas: parseInt(id_kelas)
        },
        include: {
            kelas: {
                include: {
                    matakuliah: true,
                    dosen: {
                        select: {
                            id_user: true,
                            nama: true
                        }
                    }
                }
            }
        }
    });
    
    res.status(201).json({ 
        status: "success", 
        message: "Enrolled in class successfully",
        data: peserta
    });
});

exports.dropKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const id_mahasiswa = req.user.id_user;
    
    const peserta = await prisma.pesertaKelas.findUnique({
        where: {
            id_mahasiswa_id_kelas: {
                id_mahasiswa,
                id_kelas: parseInt(id)
            }
        }
    });
    
    if (!peserta || peserta.deletedAt) {
        return res.status(404).json({ 
            status: "error", 
            message: "Not enrolled in this class" 
        });
    }
    
    await prisma.pesertaKelas.update({
        where: {
            id_mahasiswa_id_kelas: {
                id_mahasiswa,
                id_kelas: parseInt(id)
            }
        },
        data: { deletedAt: new Date() }
    });
    
    res.status(200).json({ 
        status: "success", 
        message: "Dropped class successfully" 
    });
});

exports.getKelasKu = asyncHandler(async (req, res) => {
    const id_mahasiswa = req.user.id_user;
    
    const pesertaKelas = await prisma.pesertaKelas.findMany({
        where: { 
            id_mahasiswa,
            deletedAt: null
        },
        include: {
            kelas: {
                where: { deletedAt: null },
                include: {
                    matakuliah: true,
                    dosen: {
                        select: {
                            id_user: true,
                            nama: true,
                            username: true
                        }
                    }
                }
            }
        },
        orderBy: { createdAt: 'desc' }
    });
    
    res.status(200).json({ 
        status: "success", 
        data: pesertaKelas 
    });
});

exports.getPesertaKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    
    // Validate kelas exists
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id),
            deletedAt: null 
        }
    });
    
    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }
    
    // Check authorization
    if (req.user.role === 'DOSEN' && req.user.id_user !== kelas.id_dosen) {
        return res.status(403).json({ 
            status: "error", 
            message: "You can only view peserta for your own classes" 
        });
    }
    
    const peserta = await prisma.pesertaKelas.findMany({
        where: { 
            id_kelas: parseInt(id),
            deletedAt: null
        },
        include: {
            mahasiswa: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true
                }
            }
        },
        orderBy: { 
            mahasiswa: {
                nama: 'asc'
            }
        }
    });
    
    res.status(200).json({ 
        status: "success", 
        data: peserta 
    });
});

// ==================== ABSENSI CONTROLLERS ====================

exports.openAbsensi = asyncHandler(async (req, res) => {
    // Dosen/Admin membuka sesi absensi untuk kelas tertentu
    const { id_kelas, type_absensi, latitude, longitude, radius_meter, mulai, selesai, pjj } = req.body;
    const id_user = req.user.id_user;

    if (req.user.role !== 'DOSEN' && req.user.role !== 'ADMIN') {
        return res.status(403).json({ 
            status: "error", 
            message: "Not authorized to open absensi" 
        });
    }

    // Validate kelas exists
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id_kelas),
            deletedAt: null 
        }
    });

    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }

    // If DOSEN, check if teaching this kelas
    if (req.user.role === 'DOSEN' && kelas.id_dosen !== req.user.id_user) {
        return res.status(403).json({ 
            status: "error", 
            message: "Not authorized for this class" 
        });
    }

    // Validate type_absensi enum
    if (!['REMOTE_ABSENSI', 'LOKAL_ABSENSI'].includes(type_absensi)) {
        return res.status(400).json({ 
            status: "error", 
            message: "Invalid type_absensi. Must be REMOTE_ABSENSI or LOKAL_ABSENSI" 
        });
    }

    // Validate coordinates
    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);

    if (type_absensi === 'REMOTE_ABSENSI' && !pjj) {
        lat = parseFloat(latitude);
        lng = parseFloat(longitude);
        radius = parseInt(radius_meter);

        if (
        isNaN(lat) || isNaN(lng) || isNaN(radius) ||
        lat < -90 || lat > 90 || lng < -180 || lng > 180 || radius <= 0
        ) {
        return res.status(400).json({
            status: "error",
            message: "Invalid coordinates or radius for REMOTE_ABSENSI"
        });
        }
    }

    // Validate mulai and selesai
    const mulaiTime = new Date(mulai);
    const selesaiTime = new Date(selesai);

    if (isNaN(mulaiTime.getTime()) || isNaN(selesaiTime.getTime()) || mulaiTime >= selesaiTime) {
        return res.status(400).json({ 
            status: "error", 
            message: "Invalid mulai or selesai time" 
        });
    }

    // Create absensi session
    const sesi = await prisma.sesiAbsensi.create({
        data: {
        id_kelas: parseInt(id_kelas),
        type_absensi,
        latitude: lat,
        longitude: lng,
        radius_meter: radius,
        mulai: mulaiTime,
        selesai: selesaiTime,
        status: true,
        createdBy: id_user
        }
    });

    res.status(201).json({ 
        status: "success", 
        message: "Absensi session opened successfully",
        data: sesi
    });

});

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

exports.createAbsensi = asyncHandler(async (req, res) => {
  const { id_kelas, id_sesi_absensi, latitude, longitude } = req.body;
  const id_user = req.user.id_user;

  const kelas = await prisma.kelas.findFirst({
    where: {
      id_kelas: parseInt(id_kelas),
      deletedAt: null
    }
  });

  if (!kelas) {
    return res.status(404).json({
      status: "error",
      message: "Kelas not found"
    });
  }

  if (req.user.role === 'MAHASISWA') {
    const peserta = await prisma.pesertaKelas.findFirst({
      where: {
        id_mahasiswa: id_user,
        id_kelas: parseInt(id_kelas),
        deletedAt: null
      }
    });

    if (!peserta) {
      return res.status(403).json({
        status: "error",
        message: "Not enrolled in this class"
      });
    }
  }

  const sesi = await prisma.sesiAbsensi.findFirst({
    where: {
      id_sesi_absensi: parseInt(id_sesi_absensi),
      id_kelas: parseInt(id_kelas),
      deletedAt: null,
      status: 'OPEN'
    }
  });

  if (!sesi) {
    return res.status(404).json({
      status: "error",
      message: "Sesi absensi tidak ditemukan atau sudah ditutup"
    });
  }

  const now = new Date();
  if (now < sesi.mulai || now > sesi.selesai) {
    return res.status(400).json({
      status: "error",
      message: "Di luar waktu absensi"
    });
  }

  const existingAbsensi = await prisma.absensi.findFirst({
    where: {
      id_user,
      id_sesi_absensi: sesi.id_sesi_absensi,
      deletedAt: null
    }
  });

  if (existingAbsensi) {
    return res.status(409).json({
      status: "error",
      message: "Sudah melakukan absensi pada sesi ini"
    });
  }

  const lat = parseFloat(latitude);
  const lng = parseFloat(longitude);

  if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return res.status(400).json({
      status: "error",
      message: "Invalid coordinates"
    });
  }

  if (sesi.type_absensi === 'REMOTE_ABSENSI' && sesi.latitude !== null && sesi.longitude !== null && sesi.radius_meter !== null) {
    const distance = haversineDistance(
      sesi.latitude,
      sesi.longitude,
      lat,
      lng
    );

    if (distance > sesi.radius_meter) {
      return res.status(403).json({
        status: "error",
        message: "Lokasi di luar area absensi"
      });
    }
  }

  // TODO: kalau LOKAL_ABSENSI + face recognition:
  // terima flag / hasil dari service face-recognition di sini

  await prisma.$executeRaw`
    INSERT INTO absensi (id_user, id_kelas, id_sesi_absensi, type_absensi, koordinat)
    VALUES (
      ${id_user},
      ${parseInt(id_kelas)},
      ${sesi.id_sesi_absensi},
      ${sesi.type_absensi}::type_absensi,
      POINT(${lng}, ${lat})
    )
  `;

  const absensi = await prisma.absensi.findFirst({
    where: {
      id_user,
      id_sesi_absensi: sesi.id_sesi_absensi
    },
    orderBy: { createdAt: 'desc' },
    include: {
      kelas: {
        include: {
          matakuliah: true
        }
      },
      sesiAbsensi: true
    }
  });

  res.status(201).json({
    status: "success",
    message: "Absensi recorded successfully",
    data: absensi
  });
});


exports.getAbsensiKu = asyncHandler(async (req, res) => {
    const id_user = req.user.id_user;
    const { id_kelas, type_absensi, page = 1, limit = 10 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const where = { 
        id_user,
        deletedAt: null
    };
    
    if (id_kelas) where.id_kelas = parseInt(id_kelas);
    if (type_absensi) where.type_absensi = type_absensi;
    
    const [absensi, total] = await prisma.$transaction([
        prisma.absensi.findMany({
            where,
            skip,
            take: parseInt(limit),
            include: {
                kelas: {
                    include: {
                        matakuliah: true,
                        dosen: {
                            select: {
                                id_user: true,
                                nama: true
                            }
                        }
                    }
                }
            },
            orderBy: { createdAt: 'desc' }
        }),
        prisma.absensi.count({ where })
    ]);
    
    res.status(200).json({ 
        status: "success", 
        data: absensi,
        pagination: {
            total,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(total / parseInt(limit))
        }
    });
});

exports.getAbsensiKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { type_absensi, date, page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    // Validate kelas exists
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id),
            deletedAt: null 
        }
    });
    
    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }
    
    // Check authorization
    if (req.user.role === 'DOSEN' && req.user.id_user !== kelas.id_dosen) {
        return res.status(403).json({ 
            status: "error", 
            message: "You can only view absensi for your own classes" 
        });
    }
    
    const where = { 
        id_kelas: parseInt(id),
        deletedAt: null
    };
    
    if (type_absensi) where.type_absensi = type_absensi;
    
    // Filter by date if provided
    if (date) {
        const targetDate = new Date(date);
        targetDate.setHours(0, 0, 0, 0);
        const nextDate = new Date(targetDate);
        nextDate.setDate(nextDate.getDate() + 1);
        
        where.createdAt = {
            gte: targetDate,
            lt: nextDate
        };
    }
    
    const [absensi, total] = await prisma.$transaction([
        prisma.absensi.findMany({
            where,
            skip,
            take: parseInt(limit),
            include: {
                user: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true,
                        role: true
                    }
                }
            },
            orderBy: { createdAt: 'desc' }
        }),
        prisma.absensi.count({ where })
    ]);
    
    res.status(200).json({ 
        status: "success", 
        data: absensi,
        pagination: {
            total,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(total / parseInt(limit))
        }
    });
});

exports.getAbsensiStats = asyncHandler(async (req, res) => {
    const { id } = req.params;
    
    // Validate kelas exists
    const kelas = await prisma.kelas.findFirst({
        where: { 
            id_kelas: parseInt(id),
            deletedAt: null 
        }
    });
    
    if (!kelas) {
        return res.status(404).json({ 
            status: "error", 
            message: "Kelas not found" 
        });
    }
    
    // Check authorization
    if (req.user.role === 'DOSEN' && req.user.id_user !== kelas.id_dosen) {
        return res.status(403).json({ 
            status: "error", 
            message: "You can only view statistics for your own classes" 
        });
    }
    
    // Get total peserta
    const totalPeserta = await prisma.pesertaKelas.count({
        where: {
            id_kelas: parseInt(id),
            deletedAt: null
        }
    });
    
    // Get total absensi
    const totalAbsensi = await prisma.absensi.count({
        where: {
            id_kelas: parseInt(id),
            deletedAt: null
        }
    });
    
    // Get absensi by type
    const absensiByType = await prisma.absensi.groupBy({
        by: ['type_absensi'],
        where: {
            id_kelas: parseInt(id),
            deletedAt: null
        },
        _count: {
            id_absensi: true
        }
    });
    
    // Get absensi by mahasiswa
    const absensiPerMahasiswa = await prisma.absensi.groupBy({
        by: ['id_user'],
        where: {
            id_kelas: parseInt(id),
            deletedAt: null,
            user: {
                role: 'MAHASISWA'
            }
        },
        _count: {
            id_absensi: true
        }
    });
    
    res.status(200).json({ 
        status: "success", 
        data: {
            totalPeserta,
            totalAbsensi,
            absensiByType: absensiByType.reduce((acc, item) => {
                acc[item.type_absensi] = item._count.id_absensi;
                return acc;
            }, {}),
            totalMahasiswaAbsensi: absensiPerMahasiswa.length,
            averageAbsensiPerMahasiswa: absensiPerMahasiswa.length > 0 
                ? (absensiPerMahasiswa.reduce((sum, item) => sum + item._count.id_absensi, 0) / absensiPerMahasiswa.length).toFixed(2)
                : 0
        }
    });
});


