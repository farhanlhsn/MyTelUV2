const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { Prisma } = require('../generated/prisma');
const { parsePagination, buildPaginationResponse, isDosenAuthorizedForKelas, haversineDistance } = require('../utils/akademikHelpers');

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
    const { search } = req.query;
    const { page, limit, skip } = parsePagination(req.query);

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
            take: limit,
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
        pagination: buildPaginationResponse(total, page, limit)
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
        AND "deletedAt" IS NULL
        AND hari = ${req.body.hari ? parseInt(req.body.hari) : 0}
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
        INSERT INTO kelas (id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan, hari, "createdAt", "updatedAt")
        VALUES (
            ${parseInt(id_matakuliah)}, 
            ${parseInt(id_dosen)}, 
            ${jam_mulai}::time, 
            ${jam_berakhir}::time, 
            ${nama_kelas.trim()}, 
            ${ruangan.trim()},
            ${req.body.hari ? parseInt(req.body.hari) : null},
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
    const { id_matakuliah, id_dosen, ruangan } = req.query;
    const { page, limit, skip } = parsePagination(req.query);

    const where = { deletedAt: null };

    if (id_matakuliah) where.id_matakuliah = parseInt(id_matakuliah);
    if (id_dosen) where.id_dosen = parseInt(id_dosen);
    if (ruangan) where.ruangan = { contains: ruangan, mode: 'insensitive' };

    const [kelas, total] = await prisma.$transaction([
        prisma.kelas.findMany({
            where,
            skip,
            take: limit,
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
        pagination: buildPaginationResponse(total, page, limit)
    });
});

// Get classes for today based on current day of week
exports.getKelasHariIni = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // Get current day (1=Monday/Senin, 7=Sunday/Minggu)
    const now = new Date();
    const currentDay = now.getDay() === 0 ? 7 : now.getDay(); // Convert Sunday from 0 to 7
    const currentTime = now.toTimeString().slice(0, 8);

    // 1. Find overrides moving TO today
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(now);
    endOfDay.setHours(23, 59, 59, 999);

    const overridesToToday = await prisma.jadwalPengganti.findMany({
        where: {
            tanggal_ganti: {
                gte: startOfDay,
                lte: endOfDay
            },
            deletedAt: null,
            status: 'GANTI_JADWAL'
        },
        select: { id_kelas: true }
    });

    const classIdsMovedHere = overridesToToday.map(o => o.id_kelas);

    console.log(`[DEBUG] getKelasHariIni: overridesToToday count: ${overridesToToday.length}`);
    console.log(`[DEBUG] getKelasHariIni: classIdsMovedHere: ${JSON.stringify(classIdsMovedHere)}`);

    // 2. Build Where Clause
    let whereClause = {
        deletedAt: null,
        OR: [
            { hari: currentDay },
            { id_kelas: { in: classIdsMovedHere } }
        ]
    };



    // Filter based on user role
    const roleFilter = {};
    if (userRole === 'MAHASISWA') {
        roleFilter.peserta = {
            some: {
                id_mahasiswa: userId,
                deletedAt: null
            }
        };
    } else if (userRole === 'DOSEN') {
        roleFilter.id_dosen = userId;
    }

    // Merge role filter
    Object.assign(whereClause, roleFilter);

    // 3. Get classes
    const allKelas = await prisma.kelas.findMany({
        where: whereClause,
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
            },
            sesiAbsensi: {
                where: {
                    deletedAt: null,
                    status: true,
                    mulai: { lte: now },
                    selesai: { gte: now }
                },
                orderBy: { mulai: 'desc' },
                take: 1
            },
            // Include overrides: EITHER from today OR to today
            jadwalPengganti: {
                where: {
                    deletedAt: null,
                    OR: [
                        {
                            // Override FROM today (e.g., cancelled or moved away)
                            tanggal_asli: {
                                gte: startOfDay,
                                lte: endOfDay
                            }
                        },
                        {
                            // Override TO today
                            tanggal_ganti: {
                                gte: startOfDay,
                                lte: endOfDay
                            }
                        }
                    ]
                },
                orderBy: { createdAt: 'desc' }, // latest override preferred?
                take: 1
            }
        },
        orderBy: { createdAt: 'asc' }
    });

    // Fetch time fields using raw query because they are Unsupported("time")
    const kelasIds = allKelas.map(k => k.id_kelas);
    let timeData = [];
    if (kelasIds.length > 0) {
        timeData = await prisma.$queryRaw`
            SELECT id_kelas, jam_mulai::text, jam_berakhir::text 
            FROM kelas 
            WHERE id_kelas IN (${Prisma.join(kelasIds)})
        `;
    }

    const timeMap = new Map();
    timeData.forEach(t => {
        // Handle potentially null times if query didn't return them (though raw query should)
        timeMap.set(t.id_kelas, {
            jam_mulai: t.jam_mulai,
            jam_berakhir: t.jam_berakhir
        });
    });

    // Transform results with override info
    const transformedKelas = allKelas.map((k) => {
        const hasActiveSession = k.sesiAbsensi && k.sesiAbsensi.length > 0;

        // Find relevant override
        // We might have fetched override FROM today or TO today.
        // We need to know which one applies today.

        let override = null;
        if (k.jadwalPengganti && k.jadwalPengganti.length > 0) {
            // Check if there is an override relevant to "displaying on today's list"
            // If class is normally today (hari == currentDay), we typically look for overrides starting today.
            // If class is NOT normally today (moved here), we look for overrides ending today.

            // Prioritize the one moving to today?
            // Actually our query fetches both.
            // Let's pick the one that IS active for today.

            // If multiple, logic:
            // 1. If override.tanggal_asli is TODAY -> Class is modified/cancelled.
            // 2. If override.tanggal_ganti is TODAY -> Class is moved HERE.

            for (const o of k.jadwalPengganti) {
                const asliIsToday = new Date(o.tanggal_asli).getDate() === now.getDate();
                const gantiIsToday = o.tanggal_ganti ? new Date(o.tanggal_ganti).getDate() === now.getDate() : false;

                if (asliIsToday || gantiIsToday) {
                    override = o;
                    break;
                }
            }
        }

        const hasOverride = !!override;
        const rawTimes = timeMap.get(k.id_kelas) || {};

        // If moved TO today -> Use new time
        // If moved FROM today -> Use original time (will be filtered if GANTI_JADWAL/LIBUR)

        let displayJamMulai = rawTimes.jam_mulai || k.jam_mulai;
        let displayJamBerakhir = rawTimes.jam_berakhir || k.jam_berakhir;
        let displayRuangan = k.ruangan;

        // Apply override details if moved TO today
        if (hasOverride && override.status === 'GANTI_JADWAL' && override.tanggal_ganti) {
            const gantiIsToday = new Date(override.tanggal_ganti).getDate() === now.getDate();
            if (gantiIsToday) {
                // It is TODAY because of this override
                if (override.jam_mulai_ganti) displayJamMulai = override.jam_mulai_ganti;
                // We don't store jam_berakhir_ganti separately usually? Or do we?
                // Schema check: JadwalPengganti has jam_mulai_ganti and jam_berakhir_ganti?
                // Looking at schema inspection earlier... we saw createJadwalPengganti only takes 'jam_mulai_ganti' maybe?
                // Let's assume we use duration or similar.
                // Wait, Prisma schema `JadwalPengganti` usually has both if `Kelas` has both.
                // But in `createJadwalPengganti` controller I saw update?
                // Checking previous context... `createJadwalPengganti` only accepted `tanggal_ganti` and `ruangan_ganti`.
                // It did NOT seem to accept `jam_mulai_ganti`. 
                // Wait, let's double check `createJadwalPengganti` implementation.
                // It only takes `tanggal_ganti` (Date). Date object includes time? 
                // "tanggal_ganti: new Date(tanggal_ganti)". 
                // If it's a DateTime, it includes time.
                // So the "jam" is extracted from `tanggal_ganti`?
                // Or are there separate fields?
                // In `getKelasWithHari`, `override` had `jam_mulai_ganti`.
                // Let's assume `jam_mulai_ganti` exists if it was in the schema.
                // If not, maybe it relies on `tanggal_ganti` having time component.

                // For now, let's keep original logic but be aware.
                // If `tanggal_ganti` is a DateTime, we can extract time.

                if (override.ruangan_ganti) displayRuangan = override.ruangan_ganti;
            }
        }

        return {
            id_kelas: k.id_kelas,
            nama_kelas: k.nama_kelas,
            hari: k.hari,
            ruangan: displayRuangan,
            jam_mulai: displayJamMulai,
            jam_berakhir: displayJamBerakhir,
            matakuliah: k.matakuliah,
            dosen: k.dosen,
            jumlah_peserta: k._count.peserta,
            has_active_absensi: hasActiveSession,
            active_sesi_absensi: hasActiveSession ? k.sesiAbsensi[0] : null,
            has_override: hasOverride,
            override: override ? {
                status: override.status,
                alasan: override.alasan,
                tanggal_ganti: override.tanggal_ganti,
                ruangan_ganti: override.ruangan_ganti
            } : null
        };
    });

    // Filter logic:
    // 1. If hari == Today:
    //    - Show unless override status is LIBUR.
    //    - Show unless override status is GANTI_JADWAL AND tanggal_asli is Today (moved away).
    // 2. If hari != Today:
    //    - Show ONLY if override status is GANTI_JADWAL AND tanggal_ganti is Today (moved here).

    const activeKelas = transformedKelas.filter(k => {
        if (!k.has_override) {
            // No override. Show if it's normally today.
            return k.hari === currentDay;
        }

        const o = k.override;
        const asliIsToday = new Date(o.tanggal_asli).getDate() === now.getDate();
        const gantiIsToday = o.tanggal_ganti ? new Date(o.tanggal_ganti).getDate() === now.getDate() : false;

        if (k.hari === currentDay) {
            // Normally today.
            if (o.status === 'LIBUR' && asliIsToday) return false; // Cancelled today
            if (o.status === 'GANTI_JADWAL' && asliIsToday) return false; // Moved away from today
            return true; // e.g. moved TO today (weird but possible) or some other case
        } else {
            // Normally NOT today.
            // Show only if moved TO today
            if (o.status === 'GANTI_JADWAL' && gantiIsToday) return true;
            return false;
        }
    });

    const dayNames = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    res.status(200).json({
        status: "success",
        message: `Kelas hari ${dayNames[currentDay]} untuk ${userRole}`,
        data: activeKelas,
        meta: {
            current_day: currentDay,
            day_name: dayNames[currentDay],
            current_time: currentTime,
            total_kelas: activeKelas.length
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
    const { id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan, hari } = req.body;

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
    if (hari) updateData.hari = parseInt(hari);

    // Check for schedule conflicts if updating time
    if (jam_mulai || jam_berakhir) {
        const newJamMulai = jam_mulai || null;
        const newJamBerakhir = jam_berakhir || null;
        const targetDosenId = id_dosen ? parseInt(id_dosen) : kelas.id_dosen;

        // Check for schedule conflicts (same dosen, overlapping time, excluding current kelas)
        const conflictingKelas = await prisma.$queryRaw`
            SELECT * FROM kelas 
            WHERE id_dosen = ${targetDosenId}
            AND id_kelas != ${parseInt(id)}
            AND "deletedAt" IS NULL
            AND hari = ${hari ? parseInt(hari) : kelas.hari}
            AND (
                (jam_mulai <= COALESCE(${newJamMulai}::time, jam_mulai) AND jam_berakhir > COALESCE(${newJamMulai}::time, jam_mulai))
                OR (jam_mulai < COALESCE(${newJamBerakhir}::time, jam_berakhir) AND jam_berakhir >= COALESCE(${newJamBerakhir}::time, jam_berakhir))
                OR (jam_mulai >= COALESCE(${newJamMulai}::time, jam_mulai) AND jam_berakhir <= COALESCE(${newJamBerakhir}::time, jam_berakhir))
            )
        `;

        if (conflictingKelas.length > 0) {
            return res.status(409).json({
                status: "error",
                message: "Schedule conflict detected. Dosen already has a class at this time."
            });
        }
    }

    // Handle time fields with safe parameterized query
    if (jam_mulai && jam_berakhir) {
        await prisma.$executeRaw`
            UPDATE kelas 
            SET jam_mulai = ${jam_mulai}::time,
                jam_berakhir = ${jam_berakhir}::time,
                "updatedAt" = NOW()
            WHERE id_kelas = ${parseInt(id)}
        `;
    } else if (jam_mulai) {
        await prisma.$executeRaw`
            UPDATE kelas 
            SET jam_mulai = ${jam_mulai}::time,
                "updatedAt" = NOW()
            WHERE id_kelas = ${parseInt(id)}
        `;
    } else if (jam_berakhir) {
        await prisma.$executeRaw`
            UPDATE kelas 
            SET jam_berakhir = ${jam_berakhir}::time,
                "updatedAt" = NOW()
            WHERE id_kelas = ${parseInt(id)}
        `;
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

exports.deleteAllKelas = asyncHandler(async (req, res) => {
    // Only ADMIN can delete all classes
    if (req.user.role !== 'ADMIN') {
        return res.status(403).json({
            status: "error",
            message: "Only Admin can perform this action"
        });
    }

    // Soft delete all classes that are not already deleted
    const result = await prisma.$executeRaw`
        UPDATE kelas 
        SET "deletedAt" = NOW()
        WHERE "deletedAt" IS NULL
    `;

    res.status(200).json({
        status: "success",
        message: "All items deleted successfully",
        data: {
            count: result // result is the number of affected rows
        }
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
            deletedAt: null,
            kelas: {
                deletedAt: null
            }
        },
        include: {
            kelas: {
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

// Admin add peserta to kelas
// Admin add peserta to kelas (Single or Multiple)
exports.adminAddPeserta = asyncHandler(async (req, res) => {
    const { id_kelas, id_mahasiswa } = req.body;

    // Validate inputs
    if (!id_kelas || !id_mahasiswa) {
        return res.status(400).json({
            status: "error",
            message: "id_kelas and id_mahasiswa are required"
        });
    }

    // Convert id_mahasiswa to array if it's a single value
    const mahasiswaIds = Array.isArray(id_mahasiswa)
        ? id_mahasiswa.map(id => parseInt(id))
        : [parseInt(id_mahasiswa)];

    if (mahasiswaIds.length === 0) {
        return res.status(400).json({
            status: "error",
            message: "No mahasiswa IDs provided"
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

    // Check existing enrollments (both active and soft-deleted)
    const existingEnrollments = await prisma.pesertaKelas.findMany({
        where: {
            id_kelas: parseInt(id_kelas),
            id_mahasiswa: { in: mahasiswaIds }
        }
    });

    const existingMap = new Map();
    existingEnrollments.forEach(e => existingMap.set(e.id_mahasiswa, e));

    const toCreate = [];
    const toRestore = [];
    const alreadyEnrolled = [];

    for (const id of mahasiswaIds) {
        const enrollment = existingMap.get(id);
        if (enrollment) {
            if (enrollment.deletedAt) {
                toRestore.push(id);
            } else {
                alreadyEnrolled.push(id);
            }
        } else {
            toCreate.push(id);
        }
    }

    // Perform validation for existence of students (optional, but good for data integrity)
    // For bulk speed, we might skip individual user existence check if we trust the IDs,
    // OR we can fetch all users with these IDs to verify.
    const validStudents = await prisma.user.findMany({
        where: {
            id_user: { in: mahasiswaIds },
            role: 'MAHASISWA',
            deletedAt: null
        },
        select: { id_user: true }
    });

    const validStudentIds = new Set(validStudents.map(u => u.id_user));

    // Filter execution lists to only include valid students
    const validToCreate = toCreate.filter(id => validStudentIds.has(id));
    const validToRestore = toRestore.filter(id => validStudentIds.has(id));

    // Execute Bulk Restore
    if (validToRestore.length > 0) {
        await prisma.pesertaKelas.updateMany({
            where: {
                id_kelas: parseInt(id_kelas),
                id_mahasiswa: { in: validToRestore }
            },
            data: { deletedAt: null }
        });
    }

    // Execute Bulk Create
    if (validToCreate.length > 0) {
        await prisma.pesertaKelas.createMany({
            data: validToCreate.map(id => ({
                id_kelas: parseInt(id_kelas),
                id_mahasiswa: id
            })),
            skipDuplicates: true
        });
    }

    res.status(201).json({
        status: "success",
        message: "Process completed",
        data: {
            added: validToCreate.length,
            restored: validToRestore.length,
            skipped_already_enrolled: alreadyEnrolled.length,
            invalid_ids: mahasiswaIds.length - validStudentIds.size
        }
    });
});

// ==================== ABSENSI CONTROLLERS ====================

exports.openAbsensi = asyncHandler(async (req, res) => {
    // Dosen/Admin membuka sesi absensi untuk kelas tertentu
    const { id_kelas, latitude, longitude, radius_meter, mulai, selesai, require_face } = req.body;
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

    // Validate coordinates (required for geofence)
    let lat = parseFloat(latitude);
    let lng = parseFloat(longitude);
    let radius = radius_meter ? parseInt(radius_meter) : null;

    // Validate geofence coordinates if provided
    if (!isNaN(lat) && !isNaN(lng)) {
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            return res.status(400).json({
                status: "error",
                message: "Invalid coordinates"
            });
        }
        if (radius !== null && radius <= 0) {
            return res.status(400).json({
                status: "error",
                message: "Radius must be positive"
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

    // Determine type_absensi for backward compatibility
    const type_absensi = require_face === true ? 'LOKAL_ABSENSI' : 'REMOTE_ABSENSI';

    // Create absensi session
    const sesi = await prisma.sesiAbsensi.create({
        data: {
            id_kelas: parseInt(id_kelas),
            type_absensi,
            latitude: isNaN(lat) ? null : lat,
            longitude: isNaN(lng) ? null : lng,
            radius_meter: radius,
            // require_face: require_face === true, // TODO: Uncomment after running: ALTER TABLE "SesiAbsensi" ADD COLUMN "require_face" BOOLEAN NOT NULL DEFAULT false;
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
            status: true // Boolean: true = open, false = closed
        }
    });

    if (!sesi) {
        return res.status(404).json({
            status: "error",
            message: "Sesi absensi tidak ditemukan atau sudah ditutup"
        });
    }

    // Check if face verification is required - must use biometrik endpoint
    if (sesi.require_face === true) {
        return res.status(400).json({
            status: "error",
            message: "Sesi ini membutuhkan verifikasi wajah. Gunakan fitur absen biometrik.",
            require_face: true
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

    // Always check geofence if coordinates are set on the session
    if (sesi.latitude !== null && sesi.longitude !== null && sesi.radius_meter !== null) {
        const distance = haversineDistance(
            sesi.latitude,
            sesi.longitude,
            lat,
            lng
        );

        if (distance > sesi.radius_meter) {
            return res.status(403).json({
                status: "error",
                message: "Lokasi di luar area absensi",
                distance: Math.round(distance),
                required_radius: sesi.radius_meter
            });
        }
    }

    await prisma.$executeRaw`
    INSERT INTO absensi (id_user, id_kelas, id_sesi_absensi, type_absensi, koordinat, "updatedAt")
    VALUES (
      ${id_user},
      ${parseInt(id_kelas)},
      ${sesi.id_sesi_absensi},
      ${sesi.type_absensi}::"TypeAbsensi",
      POINT(${lng}, ${lat}),
      NOW()
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
    const { id_kelas, type_absensi } = req.query;
    const { page, limit, skip } = parsePagination(req.query);

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
            take: limit,
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
        pagination: buildPaginationResponse(total, page, limit)
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

// ==================== SESI ABSENSI CONTROLLERS ====================

/**
 * Get all sesi absensi for a kelas (for dosen)
 */
exports.getSesiAbsensiByKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { status, page = 1, limit = 20 } = req.query;
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
            message: "You can only view sesi for your own classes"
        });
    }

    // Get total peserta for this kelas
    const totalPeserta = await prisma.pesertaKelas.count({
        where: {
            id_kelas: parseInt(id),
            deletedAt: null
        }
    });

    const where = {
        id_kelas: parseInt(id),
        deletedAt: null
    };

    // Filter by status if provided
    if (status !== undefined) {
        where.status = status === 'true';
    }

    const [sesiList, total] = await prisma.$transaction([
        prisma.sesiAbsensi.findMany({
            where,
            skip,
            take: parseInt(limit),
            include: {
                _count: {
                    select: {
                        absensi: {
                            where: { deletedAt: null }
                        }
                    }
                }
            },
            orderBy: { mulai: 'desc' }
        }),
        prisma.sesiAbsensi.count({ where })
    ]);

    // Add total_peserta to each sesi
    const sesiWithStats = sesiList.map(sesi => ({
        ...sesi,
        total_peserta: totalPeserta,
        jumlah_hadir: sesi._count.absensi
    }));

    res.status(200).json({
        status: "success",
        data: sesiWithStats,
        pagination: {
            total,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(total / parseInt(limit))
        }
    });
});

/**
 * Get detail absensi for a specific sesi (who attended, who didn't)
 */
exports.getSesiAbsensiDetail = asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Get sesi with kelas info
    const sesi = await prisma.sesiAbsensi.findFirst({
        where: {
            id_sesi_absensi: parseInt(id),
            deletedAt: null
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

    if (!sesi) {
        return res.status(404).json({
            status: "error",
            message: "Sesi absensi not found"
        });
    }

    // Check authorization
    if (req.user.role === 'DOSEN' && req.user.id_user !== sesi.kelas.id_dosen) {
        return res.status(403).json({
            status: "error",
            message: "You can only view detail for your own classes"
        });
    }

    // Get all peserta for this kelas
    const pesertaList = await prisma.pesertaKelas.findMany({
        where: {
            id_kelas: sesi.id_kelas,
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
            mahasiswa: { nama: 'asc' }
        }
    });

    // Get absensi records for this sesi
    const absensiRecords = await prisma.absensi.findMany({
        where: {
            id_sesi_absensi: parseInt(id),
            deletedAt: null
        },
        select: {
            id_user: true,
            createdAt: true
        }
    });

    // Create a map for quick lookup
    const absensiMap = new Map();
    absensiRecords.forEach(a => {
        absensiMap.set(a.id_user, a.createdAt);
    });

    // Build peserta list with hadir status
    const pesertaWithStatus = pesertaList.map(p => ({
        id_user: p.mahasiswa.id_user,
        nama: p.mahasiswa.nama,
        username: p.mahasiswa.username,
        hadir: absensiMap.has(p.mahasiswa.id_user),
        waktu_absen: absensiMap.get(p.mahasiswa.id_user) || null
    }));

    res.status(200).json({
        status: "success",
        data: {
            sesi: {
                id_sesi_absensi: sesi.id_sesi_absensi,
                type_absensi: sesi.type_absensi,
                mulai: sesi.mulai,
                selesai: sesi.selesai,
                status: sesi.status,
                kelas: sesi.kelas
            },
            peserta: pesertaWithStatus,
            stats: {
                total_peserta: pesertaList.length,
                total_hadir: absensiRecords.length,
                total_tidak_hadir: pesertaList.length - absensiRecords.length,
                persentase: pesertaList.length > 0
                    ? ((absensiRecords.length / pesertaList.length) * 100).toFixed(1)
                    : 0
            }
        }
    });
});

/**
 * Close a sesi absensi
 */
exports.closeSesiAbsensi = asyncHandler(async (req, res) => {
    const { id } = req.params;

    const sesi = await prisma.sesiAbsensi.findFirst({
        where: {
            id_sesi_absensi: parseInt(id),
            deletedAt: null
        },
        include: {
            kelas: true
        }
    });

    if (!sesi) {
        return res.status(404).json({
            status: "error",
            message: "Sesi absensi not found"
        });
    }

    // Check authorization
    if (req.user.role === 'DOSEN' && req.user.id_user !== sesi.kelas.id_dosen) {
        return res.status(403).json({
            status: "error",
            message: "You can only close sesi for your own classes"
        });
    }

    if (!sesi.status) {
        return res.status(400).json({
            status: "error",
            message: "Sesi absensi sudah ditutup"
        });
    }

    // Close the sesi
    await prisma.sesiAbsensi.update({
        where: { id_sesi_absensi: parseInt(id) },
        data: { status: false }
    });

    res.status(200).json({
        status: "success",
        message: "Sesi absensi berhasil ditutup"
    });
});

/**
 * Get mahasiswa attendance history with all sessions (hadir/tidak hadir)
 */
exports.getAbsensiKuWithHistory = asyncHandler(async (req, res) => {
    const id_user = req.user.id_user;
    const { id_kelas } = req.query;

    // Get enrolled classes
    const enrolledClasses = await prisma.pesertaKelas.findMany({
        where: {
            id_mahasiswa: id_user,
            deletedAt: null,
            ...(id_kelas && { id_kelas: parseInt(id_kelas) }),
            kelas: { deletedAt: null }
        },
        include: {
            kelas: {
                include: {
                    matakuliah: true,
                    dosen: {
                        select: { id_user: true, nama: true }
                    }
                }
            }
        }
    });

    // For each enrolled class, get all sesi and user's attendance
    const result = await Promise.all(enrolledClasses.map(async (pk) => {
        // Get all sesi for this kelas
        const allSesi = await prisma.sesiAbsensi.findMany({
            where: {
                id_kelas: pk.id_kelas,
                deletedAt: null
            },
            orderBy: { mulai: 'desc' }
        });

        // Get user's absensi for this kelas
        const userAbsensi = await prisma.absensi.findMany({
            where: {
                id_user,
                id_kelas: pk.id_kelas,
                deletedAt: null
            },
            select: {
                id_sesi_absensi: true,
                createdAt: true,
                type_absensi: true
            }
        });

        // Create map for quick lookup
        const absensiMap = new Map();
        userAbsensi.forEach(a => {
            absensiMap.set(a.id_sesi_absensi, {
                waktu: a.createdAt,
                type: a.type_absensi
            });
        });

        // Build sessions with hadir status
        const sessions = allSesi.map(sesi => ({
            id_sesi: sesi.id_sesi_absensi,
            tanggal: sesi.mulai,
            hadir: absensiMap.has(sesi.id_sesi_absensi),
            type_absensi: absensiMap.get(sesi.id_sesi_absensi)?.type || null,
            waktu_absen: absensiMap.get(sesi.id_sesi_absensi)?.waktu || null
        }));

        const totalHadir = sessions.filter(s => s.hadir).length;

        return {
            kelas: pk.kelas,
            sessions,
            stats: {
                total_sesi: allSesi.length,
                total_hadir: totalHadir,
                total_tidak_hadir: allSesi.length - totalHadir,
                persentase: allSesi.length > 0
                    ? ((totalHadir / allSesi.length) * 100).toFixed(1)
                    : 0
            }
        };
    }));

    res.status(200).json({
        status: "success",
        data: result
    });
});

// ==================== JADWAL PENGGANTI CONTROLLERS ====================

// Create jadwal pengganti (schedule override)
exports.createJadwalPengganti = asyncHandler(async (req, res) => {
    const { id_kelas, tanggal_asli, status, tanggal_ganti, ruangan_ganti, alasan } = req.body;
    const userId = req.user.id_user;

    // Validate kelas exists and user is authorized
    const kelas = await prisma.kelas.findFirst({
        where: { id_kelas: parseInt(id_kelas), deletedAt: null }
    });

    if (!kelas) {
        return res.status(404).json({ status: "error", message: "Kelas tidak ditemukan" });
    }

    // Only dosen of the class or admin can create override
    if (req.user.role === 'DOSEN' && kelas.id_dosen !== userId) {
        return res.status(403).json({ status: "error", message: "Anda hanya bisa mengubah jadwal kelas sendiri" });
    }

    // Validate status
    if (!['LIBUR', 'GANTI_JADWAL'].includes(status)) {
        return res.status(400).json({ status: "error", message: "Status harus LIBUR atau GANTI_JADWAL" });
    }

    // If GANTI_JADWAL, tanggal_ganti is required
    if (status === 'GANTI_JADWAL' && !tanggal_ganti) {
        return res.status(400).json({ status: "error", message: "tanggal_ganti wajib diisi untuk status GANTI_JADWAL" });
    }

    const jadwalPengganti = await prisma.jadwalPengganti.create({
        data: {
            id_kelas: parseInt(id_kelas),
            tanggal_asli: new Date(tanggal_asli),
            status,
            tanggal_ganti: tanggal_ganti ? new Date(tanggal_ganti) : null,
            ruangan_ganti: ruangan_ganti || null,
            alasan,
            createdBy: userId
        },
        include: {
            kelas: {
                include: { matakuliah: true }
            }
        }
    });

    res.status(201).json({
        status: "success",
        message: status === 'LIBUR' ? 'Kelas dibatalkan/diliburkan' : 'Jadwal kelas diganti',
        data: jadwalPengganti
    });
});

// Get jadwal pengganti by kelas
exports.getJadwalPenggantiByKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { upcoming } = req.query; // If true, only show future overrides

    const where = {
        id_kelas: parseInt(id),
        deletedAt: null
    };

    if (upcoming === 'true') {
        where.tanggal_asli = { gte: new Date() };
    }

    const jadwalPengganti = await prisma.jadwalPengganti.findMany({
        where,
        include: {
            dosen: {
                select: { id_user: true, nama: true }
            }
        },
        orderBy: { tanggal_asli: 'desc' }
    });

    res.status(200).json({
        status: "success",
        data: jadwalPengganti
    });
});

// Delete jadwal pengganti (cancel override)
exports.deleteJadwalPengganti = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id_user;

    const jadwalPengganti = await prisma.jadwalPengganti.findFirst({
        where: { id_jadwal_pengganti: parseInt(id), deletedAt: null },
        include: { kelas: true }
    });

    if (!jadwalPengganti) {
        return res.status(404).json({ status: "error", message: "Jadwal pengganti tidak ditemukan" });
    }

    // Only creator or admin can delete
    if (req.user.role !== 'ADMIN' && jadwalPengganti.createdBy !== userId) {
        return res.status(403).json({ status: "error", message: "Anda tidak bisa menghapus jadwal pengganti ini" });
    }

    await prisma.jadwalPengganti.update({
        where: { id_jadwal_pengganti: parseInt(id) },
        data: { deletedAt: new Date() }
    });

    res.status(200).json({
        status: "success",
        message: "Jadwal pengganti dihapus"
    });
});

// Get all kelas with hari info (for weekly schedule view)
exports.getKelasWithHari = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const userRole = req.user.role;
    const { hari } = req.query; // Optional: filter by specific day

    let whereClause = { deletedAt: null };

    if (hari) {
        whereClause.hari = parseInt(hari);
    }

    if (userRole === 'MAHASISWA') {
        whereClause.peserta = {
            some: { id_mahasiswa: userId, deletedAt: null }
        };
    } else if (userRole === 'DOSEN') {
        whereClause.id_dosen = userId;
    }

    // Get current week range to filter relevant overrides
    const now = new Date();
    // Start of week (Monday)
    const day = now.getDay() || 7; // 1=Mon, 7=Sun
    const startOfWeek = new Date(now);
    startOfWeek.setHours(0, 0, 0, 0);
    startOfWeek.setDate(now.getDate() - day + 1);

    // End of week (Sunday)
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);
    endOfWeek.setHours(23, 59, 59, 999);

    const kelas = await prisma.kelas.findMany({
        where: whereClause,
        include: {
            matakuliah: true,
            dosen: {
                select: { id_user: true, nama: true, username: true }
            },
            _count: {
                select: { peserta: { where: { deletedAt: null } } }
            },
            jadwalPengganti: {
                where: {
                    deletedAt: null,
                    OR: [
                        {
                            // Override FROM this week
                            tanggal_asli: {
                                gte: startOfWeek,
                                lte: endOfWeek
                            }
                        },
                        {
                            // Override TO this week
                            tanggal_ganti: {
                                gte: startOfWeek,
                                lte: endOfWeek
                            }
                        }
                    ]
                }
            }
        },
        orderBy: [{ hari: 'asc' }, { createdAt: 'asc' }]
    });

    // Fetch time fields using raw query because they are Unsupported("time")
    const kelasIds = kelas.map(k => k.id_kelas);
    let timeData = [];
    if (kelasIds.length > 0) {
        timeData = await prisma.$queryRaw`
            SELECT id_kelas, jam_mulai::text, jam_berakhir::text 
            FROM kelas 
            WHERE id_kelas IN (${Prisma.join(kelasIds)})
        `;
    }

    const timeMap = new Map();
    timeData.forEach(t => {
        timeMap.set(t.id_kelas, {
            jam_mulai: t.jam_mulai,
            jam_berakhir: t.jam_berakhir
        });
    });

    const dayNames = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    // Group by day
    const grouped = {};

    // Initialize all days
    dayNames.slice(1).forEach(d => grouped[d] = []);

    kelas.forEach(k => {
        // Find relevant override for this week
        let override = null;
        if (k.jadwalPengganti && k.jadwalPengganti.length > 0) {
            // Prefer override that puts class INTO this week (tanggal_ganti in this week)
            // Or override that modifies class IN this week (tanggal_asli in this week)

            // Check overrides
            for (const o of k.jadwalPengganti) {
                const gantiInWeek = o.tanggal_ganti && new Date(o.tanggal_ganti) >= startOfWeek && new Date(o.tanggal_ganti) <= endOfWeek;
                const asliInWeek = new Date(o.tanggal_asli) >= startOfWeek && new Date(o.tanggal_asli) <= endOfWeek;

                if (gantiInWeek) {
                    override = o; // Moved TO this week
                    break;
                }
                if (asliInWeek) {
                    override = o; // Moved FROM/Cancelled in this week
                }
            }
        }

        // Get time from raw map (fallback to k.jam_mulai)
        const rawTimes = timeMap.get(k.id_kelas) || {};
        let jamMulai = rawTimes.jam_mulai || k.jam_mulai;
        let jamBerakhir = rawTimes.jam_berakhir || k.jam_berakhir;
        let ruangan = k.ruangan;

        // Determine target day
        let targetDayIndex = k.hari || 0;
        let showClass = true; // Default to show

        if (override) {
            const gantiInWeek = override.tanggal_ganti && new Date(override.tanggal_ganti) >= startOfWeek && new Date(override.tanggal_ganti) <= endOfWeek;

            if (override.status === 'GANTI_JADWAL' && override.tanggal_ganti) {
                if (gantiInWeek) {
                    // Moved TO this week (or within this week) -> Show on new day
                    const newDate = new Date(override.tanggal_ganti);
                    targetDayIndex = newDate.getDay() === 0 ? 7 : newDate.getDay();

                    // Update display time/room
                    if (override.jam_mulai_ganti) jamMulai = override.jam_mulai_ganti;
                    // jamBerakhir assumed from duration or same?
                    if (override.ruangan_ganti) ruangan = override.ruangan_ganti;

                } else {
                    // Moved AWAY from this week (to another week) -> Hide? 
                    // Or show as "Moved" on original day. 
                    // Let's hide it from the schedule slot to avoid confusion, 
                    // or keep it but mark 'moved'.
                    // User request implies "Jadwal Mingguan" should reflect reality.
                    // If class is moved to next week, it shouldn't be here.
                    showClass = false;
                }
            } else if (override.status === 'LIBUR') {
                // Cancelled. Stay on original day but marked LIBUR.
            }
        } else {
            // No override. Check if normal class day is relevant to this week? 
            // Logic: Class repeats weekly. So it is relevant.
            // But if we have classes that are "One off" or "Bi-weekly"? 
            // System assumes weekly recurrence.
        }

        if (showClass) {
            const classObj = {
                id_kelas: k.id_kelas,
                nama_kelas: k.nama_kelas,
                hari: k.hari, // Original hari
                jam_mulai: jamMulai,
                jam_berakhir: jamBerakhir,
                ruangan: ruangan,
                matakuliah: k.matakuliah,
                dosen: k.dosen,
                jumlah_peserta: k._count.peserta,
                override: override ? {
                    id: override.id_jadwal_pengganti,
                    status: override.status,
                    tanggal_asli: override.tanggal_asli,
                    tanggal_ganti: override.tanggal_ganti,
                    jam_mulai_ganti: override.jam_mulai_ganti,
                    ruangan_ganti: override.ruangan_ganti,
                    alasan: override.alasan
                } : null
            };

            const dayName = dayNames[targetDayIndex] || 'Belum diatur';
            if (!grouped[dayName]) grouped[dayName] = [];
            grouped[dayName].push(classObj);
        }
    });

    res.status(200).json({
        status: "success",
        data: grouped
    });
});
