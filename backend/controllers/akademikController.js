const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { Prisma } = require('../generated/prisma');
const { parsePagination, buildPaginationResponse, isDosenAuthorizedForKelas, haversineDistance, isCountableSession, isUniqueViolation } = require('../utils/akademikHelpers');
const { parsePagination: clampPagination } = require('../utils/paginationHelper');
const { jakartaWeekday, jakartaDayRange, jakartaWeekRange, jakartaDateString, jakartaTimeString } = require('../utils/timezone');
const { sendAbsensiNotification } = require('../utils/firebase');

const ABSENSI_DUPLIKAT_MESSAGE = "Anda sudah melakukan absensi untuk sesi ini";

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

const KELAS_TIME_REGEX = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/;
const JAM_TIDAK_URUT_MESSAGE = "Jam berakhir harus setelah jam mulai";
const HARI_TIDAK_VALID_MESSAGE = "Hari harus bernilai 1 (Senin) sampai 7 (Minggu)";

// "8:05:00" -> seconds since midnight, so "9:00:00" and "10:00:00" compare correctly
const timeToSeconds = (time) => {
    const [hours, minutes, seconds] = String(time).split(':').map(Number);
    return hours * 3600 + minutes * 60 + seconds;
};

// Kelas.hari is optional; when given it must be 1 (Senin) .. 7 (Minggu). Returns null when absent, NaN when invalid.
const parseHari = (hari) => {
    if (hari === undefined || hari === null || hari === '') return null;
    const parsed = Number(hari);
    return Number.isInteger(parsed) && parsed >= 1 && parsed <= 7 ? parsed : NaN;
};

// Classes of the same semester on the same hari whose time overlaps and that share the dosen or the room.
// A class without hari is not on the weekly schedule, so it cannot clash.
const findJadwalBentrok = async (db, { hari, jamMulai, jamBerakhir, idDosen, ruangan, idSemester, excludeIdKelas = 0 }) => {
    if (hari === null || hari === undefined) return [];
    return db.$queryRaw`
        SELECT id_kelas, nama_kelas, id_dosen, ruangan
        FROM kelas
        WHERE "deletedAt" IS NULL
        AND hari = ${hari}
        AND id_semester IS NOT DISTINCT FROM ${idSemester}::int
        AND id_kelas <> ${excludeIdKelas}
        AND (id_dosen = ${idDosen} OR LOWER(TRIM(ruangan)) = LOWER(${ruangan}))
        AND jam_mulai < ${jamBerakhir}::time
        AND jam_berakhir > ${jamMulai}::time
    `;
};

const jadwalBentrokMessage = (bentrok, idDosen, ruangan) => (
    bentrok.id_dosen === idDosen
        ? `Jadwal bentrok: dosen sudah mengajar kelas ${bentrok.nama_kelas} pada waktu tersebut`
        : `Jadwal bentrok: Ruangan ${ruangan} sudah dipakai kelas ${bentrok.nama_kelas} pada waktu tersebut`
);

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
    if (!KELAS_TIME_REGEX.test(jam_mulai) || !KELAS_TIME_REGEX.test(jam_berakhir)) {
        return res.status(400).json({
            status: "error",
            message: "Invalid time format. Use HH:MM:SS format (e.g., 08:00:00)"
        });
    }

    if (timeToSeconds(jam_berakhir) <= timeToSeconds(jam_mulai)) {
        return res.status(400).json({
            status: "error",
            message: JAM_TIDAK_URUT_MESSAGE
        });
    }

    const hari = parseHari(req.body.hari);
    if (Number.isNaN(hari)) {
        return res.status(400).json({
            status: "error",
            message: HARI_TIDAK_VALID_MESSAGE
        });
    }

    // Find active semester
    const activeSemester = await prisma.semester.findFirst({
        where: { is_active: true, deletedAt: null }
    });
    const activeSemesterId = activeSemester ? activeSemester.id_semester : null;
    const targetKapasitas = req.body.kapasitas ? parseInt(req.body.kapasitas) : 50;
    const idDosen = parseInt(id_dosen);
    const targetRuangan = ruangan.trim();

    // Conflict check and insert together; RETURNING gives the id of this row (not "the latest row")
    const result = await prisma.$transaction(async (tx) => {
        const bentrok = await findJadwalBentrok(tx, {
            hari,
            jamMulai: jam_mulai,
            jamBerakhir: jam_berakhir,
            idDosen,
            ruangan: targetRuangan,
            idSemester: activeSemesterId
        });

        if (bentrok.length > 0) {
            return { bentrok: bentrok[0] };
        }

        const inserted = await tx.$queryRaw`
            INSERT INTO kelas (id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan, hari, kapasitas, id_semester, "createdAt", "updatedAt")
            VALUES (
                ${parseInt(id_matakuliah)},
                ${idDosen},
                ${jam_mulai}::time,
                ${jam_berakhir}::time,
                ${nama_kelas.trim()},
                ${targetRuangan},
                ${hari},
                ${targetKapasitas},
                ${activeSemesterId},
                NOW(),
                NOW()
            )
            RETURNING id_kelas
        `;

        return { idKelas: inserted[0].id_kelas };
    });

    if (result.bentrok) {
        return res.status(409).json({
            status: "error",
            message: jadwalBentrokMessage(result.bentrok, idDosen, targetRuangan)
        });
    }

    // Fetch the created kelas with relations
    const createdKelas = await prisma.kelas.findFirst({
        where: { id_kelas: result.idKelas },
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

    // Get current day in Jakarta (1=Monday/Senin, 7=Sunday/Minggu), whatever the server time zone is
    const now = new Date();
    const currentDay = jakartaWeekday(now);
    const currentTime = jakartaTimeString(now);

    // 1. Find overrides moving TO today (the Jakarta calendar day)
    const { start: startOfDay, end: endOfDay } = jakartaDayRange(now);
    const todayKey = jakartaDateString(now);
    const isToday = (date) => !!date && jakartaDateString(date) === todayKey;

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
                const asliIsToday = isToday(o.tanggal_asli);
                const gantiIsToday = isToday(o.tanggal_ganti);

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
            const gantiIsToday = isToday(override.tanggal_ganti);
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
                // Needed by the filter below to tell "cancelled/moved away today" from "moved here today"
                tanggal_asli: override.tanggal_asli,
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
        const asliIsToday = isToday(o.tanggal_asli);
        const gantiIsToday = isToday(o.tanggal_ganti);

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

    // Enforce Dosen isolation (BF22)
    if (req.user.role === 'DOSEN' && kelas.id_dosen !== req.user.id_user) {
        return res.status(403).json({
            status: "error",
            message: "You are not authorized to view this class details"
        });
    }

    res.status(200).json({
        status: "success",
        data: kelas
    });
});

exports.updateKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan, hari, kapasitas } = req.body;

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
    if ((jam_mulai && !KELAS_TIME_REGEX.test(jam_mulai)) || (jam_berakhir && !KELAS_TIME_REGEX.test(jam_berakhir))) {
        return res.status(400).json({
            status: "error",
            message: "Invalid time format. Use HH:MM:SS format (e.g., 08:00:00)"
        });
    }

    const newHari = parseHari(hari);
    if (Number.isNaN(newHari)) {
        return res.status(400).json({
            status: "error",
            message: HARI_TIDAK_VALID_MESSAGE
        });
    }

    let newKapasitas;
    if (kapasitas !== undefined && kapasitas !== null && kapasitas !== '') {
        newKapasitas = Number(kapasitas);
        if (!Number.isInteger(newKapasitas) || newKapasitas < 1) {
            return res.status(400).json({
                status: "error",
                message: "Kapasitas harus bilangan bulat minimal 1"
            });
        }
    }

    const idKelas = parseInt(id);
    const targetDosenId = id_dosen ? parseInt(id_dosen) : kelas.id_dosen;
    const targetRuangan = ruangan ? ruangan.trim() : kelas.ruangan;
    const targetHari = newHari !== null ? newHari : kelas.hari;

    // Any change to when, where or by whom the class is taught must be checked for clashes
    const scheduleChanged = Boolean(jam_mulai || jam_berakhir || ruangan || id_dosen || newHari !== null);

    // jam_* are Unsupported("time") columns: read the stored values to validate a one-sided change
    let targetJamMulai = jam_mulai;
    let targetJamBerakhir = jam_berakhir;
    if (scheduleChanged && (!jam_mulai || !jam_berakhir)) {
        const storedTimes = await prisma.$queryRaw`
            SELECT jam_mulai::text AS jam_mulai, jam_berakhir::text AS jam_berakhir
            FROM kelas
            WHERE id_kelas = ${idKelas}
        `;
        targetJamMulai = jam_mulai || storedTimes[0]?.jam_mulai;
        targetJamBerakhir = jam_berakhir || storedTimes[0]?.jam_berakhir;
    }

    if (targetJamMulai && targetJamBerakhir && timeToSeconds(targetJamBerakhir) <= timeToSeconds(targetJamMulai)) {
        return res.status(400).json({
            status: "error",
            message: JAM_TIDAK_URUT_MESSAGE
        });
    }

    // Build update data
    const updateData = {};
    if (id_matakuliah) updateData.id_matakuliah = parseInt(id_matakuliah);
    if (id_dosen) updateData.id_dosen = targetDosenId;
    if (nama_kelas) updateData.nama_kelas = nama_kelas.trim();
    if (ruangan) updateData.ruangan = targetRuangan;
    if (newHari !== null) updateData.hari = newHari;
    if (newKapasitas !== undefined) updateData.kapasitas = newKapasitas;

    // Checks and the multi-step update succeed or fail together; the row lock serialises
    // this update with enrollments and other updates of the same class
    const result = await prisma.$transaction(async (tx) => {
        await tx.$executeRaw`SELECT 1 FROM kelas WHERE id_kelas = ${idKelas} FOR UPDATE`;

        if (newKapasitas !== undefined) {
            const enrolledCount = await tx.pesertaKelas.count({
                where: { id_kelas: idKelas, deletedAt: null }
            });
            if (enrolledCount > newKapasitas) {
                return {
                    error: 400,
                    message: `Kapasitas tidak boleh kurang dari jumlah peserta saat ini (${enrolledCount})`
                };
            }
        }

        if (scheduleChanged) {
            const bentrok = await findJadwalBentrok(tx, {
                hari: targetHari,
                jamMulai: targetJamMulai,
                jamBerakhir: targetJamBerakhir,
                idDosen: targetDosenId,
                ruangan: targetRuangan,
                idSemester: kelas.id_semester,
                excludeIdKelas: idKelas
            });
            if (bentrok.length > 0) {
                return { error: 409, message: jadwalBentrokMessage(bentrok[0], targetDosenId, targetRuangan) };
            }
        }

        if (jam_mulai || jam_berakhir) {
            await tx.$executeRaw`
                UPDATE kelas
                SET jam_mulai = ${targetJamMulai}::time,
                    jam_berakhir = ${targetJamBerakhir}::time,
                    "updatedAt" = NOW()
                WHERE id_kelas = ${idKelas}
            `;
        }

        if (Object.keys(updateData).length > 0) {
            await tx.kelas.update({
                where: { id_kelas: idKelas },
                data: updateData
            });
        }

        return {};
    });

    if (result.error) {
        return res.status(result.error).json({
            status: "error",
            message: result.message
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

    const idKelas = parseInt(id_kelas);

    // Capacity check and insert run in one transaction. The class row lock makes concurrent
    // enrollments (here and in adminAddPeserta) wait, so the count cannot go stale before the insert.
    const result = await prisma.$transaction(async (tx) => {
        await tx.$executeRaw`SELECT 1 FROM kelas WHERE id_kelas = ${idKelas} FOR UPDATE`;

        // 1. Class Capacity Check (BF20)
        const currentEnrolledCount = await tx.pesertaKelas.count({
            where: {
                id_kelas: idKelas,
                deletedAt: null
            }
        });

        if (currentEnrolledCount >= kelas.kapasitas) {
            return {
                code: 400,
                body: {
                    status: "error",
                    message: "Kelas sudah penuh. Kapasitas maksimum tercapai."
                }
            };
        }

        // 2. Schedule Conflict Check (BF18)
        if (kelas.hari) {
            // Fetch target class times
            const targetTimeData = await tx.$queryRaw`
                SELECT jam_mulai::text, jam_berakhir::text 
                FROM kelas 
                WHERE id_kelas = ${idKelas}
            `;
            const targetJamMulai = targetTimeData[0]?.jam_mulai;
            const targetJamBerakhir = targetTimeData[0]?.jam_berakhir;

            if (targetJamMulai && targetJamBerakhir) {
                const conflictingClasses = await tx.$queryRaw`
                    SELECT k.id_kelas, k.nama_kelas 
                    FROM kelas k
                    INNER JOIN peserta_kelas pk ON k.id_kelas = pk.id_kelas
                    WHERE pk.id_mahasiswa = ${id_mahasiswa}
                    AND pk."deletedAt" IS NULL
                    AND k."deletedAt" IS NULL
                    AND k.hari = ${kelas.hari}
                    AND k.id_kelas != ${idKelas}
                    AND (
                        (k.jam_mulai <= ${targetJamMulai}::time AND k.jam_berakhir > ${targetJamMulai}::time)
                        OR (k.jam_mulai < ${targetJamBerakhir}::time AND k.jam_berakhir >= ${targetJamBerakhir}::time)
                        OR (k.jam_mulai >= ${targetJamMulai}::time AND k.jam_berakhir <= ${targetJamBerakhir}::time)
                    )
                `;

                if (conflictingClasses.length > 0) {
                    return {
                        code: 409,
                        body: {
                            status: "error",
                            message: `Jadwal bentrok dengan kelas yang sudah Anda ambil: ${conflictingClasses[0].nama_kelas}`
                        }
                    };
                }
            }
        }

        // Check if already enrolled
        const existingPeserta = await tx.pesertaKelas.findUnique({
            where: {
                id_mahasiswa_id_kelas: {
                    id_mahasiswa,
                    id_kelas: idKelas
                }
            }
        });

        // If already enrolled and not deleted
        if (existingPeserta && !existingPeserta.deletedAt) {
            return {
                code: 409,
                body: {
                    status: "error",
                    message: "Already enrolled in this class"
                }
            };
        }

        // If previously dropped, restore
        if (existingPeserta && existingPeserta.deletedAt) {
            await tx.pesertaKelas.update({
                where: {
                    id_mahasiswa_id_kelas: {
                        id_mahasiswa,
                        id_kelas: idKelas
                    }
                },
                data: { deletedAt: null },
            });

            return { restored: true };
        }

        // Create new enrollment
        const peserta = await tx.pesertaKelas.create({
            data: {
                id_mahasiswa,
                id_kelas: idKelas
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

        return {
            code: 201,
            body: {
                status: "success",
                message: "Enrolled in class successfully",
                data: peserta
            }
        };
    });

    if (result.restored) {
        // Fetch with relations
        const pesertaWithRelations = await prisma.pesertaKelas.findUnique({
            where: {
                id_mahasiswa_id_kelas: {
                    id_mahasiswa,
                    id_kelas: idKelas
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

    res.status(result.code).json(result.body);
});

exports.dropKelas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const id_mahasiswa = req.user.id_user;

    // Check drop deadline for active semester
    const activeSemester = await prisma.semester.findFirst({
        where: {
            is_active: true,
            deletedAt: null
        }
    });

    if (activeSemester) {
        const now = new Date();
        if (now > activeSemester.drop_deadline) {
            return res.status(400).json({
                status: "error",
                message: "Batas waktu (drop deadline) untuk membatalkan kelas di semester ini telah berakhir."
            });
        }
    }

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

// True when the mahasiswa has an active (not dropped) enrollment in the kelas
const isEnrolledInKelas = async (idKelas, idMahasiswa) => {
    const enrollment = await prisma.pesertaKelas.findFirst({
        where: {
            id_kelas: idKelas,
            id_mahasiswa: idMahasiswa,
            deletedAt: null
        }
    });
    return !!enrollment;
};

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
            message: "Kelas tidak ditemukan"
        });
    }

    // Check authorization
    if (req.user.role === 'DOSEN' && req.user.id_user !== kelas.id_dosen) {
        return res.status(403).json({
            status: "error",
            message: "Anda hanya dapat melihat peserta kelas yang Anda ajar"
        });
    }

    // A mahasiswa may only see the roster of a class they are enrolled in
    if (req.user.role === 'MAHASISWA' && !(await isEnrolledInKelas(parseInt(id), req.user.id_user))) {
        return res.status(403).json({
            status: "error",
            message: "Anda tidak terdaftar di kelas ini"
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

    // Convert id_mahasiswa to array if it's a single value (duplicates would be counted twice against kapasitas)
    const mahasiswaIds = [...new Set(Array.isArray(id_mahasiswa)
        ? id_mahasiswa.map(id => parseInt(id))
        : [parseInt(id_mahasiswa)])];

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
    const idKelas = parseInt(id_kelas);

    // Capacity check and inserts run in one transaction under the class row lock (see daftarKelas)
    const result = await prisma.$transaction(async (tx) => {
        await tx.$executeRaw`SELECT 1 FROM kelas WHERE id_kelas = ${idKelas} FOR UPDATE`;

        // Check existing enrollments (both active and soft-deleted)
        const existingEnrollments = await tx.pesertaKelas.findMany({
            where: {
                id_kelas: idKelas,
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

        // Filter execution lists to only include valid students
        const validToCreate = toCreate.filter(id => validStudentIds.has(id));
        const validToRestore = toRestore.filter(id => validStudentIds.has(id));

        // Class Capacity Check (BF20) for the whole batch
        const currentEnrolledCount = await tx.pesertaKelas.count({
            where: {
                id_kelas: idKelas,
                deletedAt: null
            }
        });
        const requested = validToCreate.length + validToRestore.length;

        if (currentEnrolledCount + requested > kelas.kapasitas) {
            return {
                error: `Kapasitas kelas tidak mencukupi. Sisa kuota: ${Math.max(0, kelas.kapasitas - currentEnrolledCount)}, diminta: ${requested}`
            };
        }

        // Execute Bulk Restore
        if (validToRestore.length > 0) {
            await tx.pesertaKelas.updateMany({
                where: {
                    id_kelas: idKelas,
                    id_mahasiswa: { in: validToRestore }
                },
                data: { deletedAt: null }
            });
        }

        // Execute Bulk Create
        if (validToCreate.length > 0) {
            await tx.pesertaKelas.createMany({
                data: validToCreate.map(id => ({
                    id_kelas: idKelas,
                    id_mahasiswa: id
                })),
                skipDuplicates: true
            });
        }

        return {
            added: validToCreate.length,
            restored: validToRestore.length,
            skipped_already_enrolled: alreadyEnrolled.length
        };
    });

    if (result.error) {
        return res.status(400).json({
            status: "error",
            message: result.error
        });
    }

    res.status(201).json({
        status: "success",
        message: "Process completed",
        data: {
            added: result.added,
            restored: result.restored,
            skipped_already_enrolled: result.skipped_already_enrolled,
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

    if (isNaN(mulaiTime.getTime()) || isNaN(selesaiTime.getTime())) {
        return res.status(400).json({
            status: "error",
            message: "Format waktu mulai atau selesai tidak valid"
        });
    }

    if (selesaiTime <= mulaiTime) {
        return res.status(400).json({
            status: "error",
            message: "Waktu selesai harus setelah waktu mulai"
        });
    }

    // Determine type_absensi for backward compatibility
    const type_absensi = require_face === true ? 'LOKAL_ABSENSI' : 'REMOTE_ABSENSI';
    const idKelas = parseInt(id_kelas);

    // Overlap check and insert in one transaction; the class row lock stops two parallel
    // requests from both passing the check
    const result = await prisma.$transaction(async (tx) => {
        await tx.$executeRaw`SELECT 1 FROM kelas WHERE id_kelas = ${idKelas} FOR UPDATE`;

        const overlappingSesi = await tx.sesiAbsensi.findFirst({
            where: {
                id_kelas: idKelas,
                deletedAt: null,
                status: true,
                mulai: { lt: selesaiTime },
                selesai: { gt: mulaiTime }
            },
            select: { id_sesi_absensi: true }
        });

        if (overlappingSesi) {
            return { overlappingSesi };
        }

        // Create absensi session
        const sesi = await tx.sesiAbsensi.create({
            data: {
                id_kelas: idKelas,
                type_absensi,
                latitude: isNaN(lat) ? null : lat,
                longitude: isNaN(lng) ? null : lng,
                radius_meter: radius,
                require_face: require_face === true,
                mulai: mulaiTime,
                selesai: selesaiTime,
                status: true,
                createdBy: id_user
            }
        });

        return { sesi };
    });

    if (result.overlappingSesi) {
        return res.status(409).json({
            status: "error",
            message: "Kelas ini sudah memiliki sesi absensi terbuka pada rentang waktu tersebut. Tutup sesi tersebut terlebih dahulu."
        });
    }

    const { sesi } = result;

    // Send push notification to all students in the class
    sendAbsensiNotification(
        parseInt(id_kelas),
        kelas.nama_kelas,
        kelas.matakuliah?.nama_matakuliah || 'Mata Kuliah'
    ).catch(err => console.error('Error triggering absensi notification:', err.message));

    res.status(201).json({
        status: "success",
        message: "Absensi session opened successfully",
        data: sesi
    });

});

exports.createAbsensi = asyncHandler(async (req, res) => {
    const { id_kelas, id_sesi_absensi, latitude, longitude } = req.body;
    const id_user = req.user.id_user;
    const isMock = req.body.is_mock_location === true || req.body.is_mock_location === 'true';

    if (isMock) {
        return res.status(400).json({
            status: "error",
            message: "Mock location / GPS spoofing terdeteksi. Absensi ditolak."
        });
    }

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
            message: ABSENSI_DUPLIKAT_MESSAGE
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

    // Step 6: Server-Side Heuristics & Impossible Travel Check
    const prevAbsensi = await prisma.$queryRaw`
        SELECT koordinat[0] AS lng, koordinat[1] AS lat, "createdAt"
        FROM absensi 
        WHERE id_user = ${id_user} 
        AND "deletedAt" IS NULL 
        ORDER BY "createdAt" DESC 
        LIMIT 1
    `;

    let credibilityScore = 100;
    let suspensionReason = "";
    let calculatedSpeedKmh = 0;
    let calculatedDistanceMeters = 0;

    if (prevAbsensi && prevAbsensi.length > 0) {
        const prevLat = parseFloat(prevAbsensi[0].lat);
        const prevLng = parseFloat(prevAbsensi[0].lng);
        const prevTime = new Date(prevAbsensi[0].createdAt);
        
        const timeDiffSeconds = Math.abs(now.getTime() - prevTime.getTime()) / 1000;
        
        if (timeDiffSeconds > 0) {
            const distMeters = haversineDistance(prevLat, prevLng, lat, lng);
            const speedMps = distMeters / timeDiffSeconds;
            calculatedSpeedKmh = Math.round(speedMps * 3.6);
            calculatedDistanceMeters = Math.round(distMeters);

            // Heuristic 1: Impossible travel (speed > 120 km/h and distance > 1000m)
            if (calculatedSpeedKmh > 120 && distMeters > 1000) {
                credibilityScore = 0;
                suspensionReason = `Impossible travel detected. Speed: ${calculatedSpeedKmh} km/h.`;
            }
            // Heuristic 2: Suspicious speed (speed > 80 km/h and distance > 1000m)
            else if (calculatedSpeedKmh > 80 && distMeters > 1000) {
                credibilityScore -= 50;
                suspensionReason = `Suspicious high travel speed: ${calculatedSpeedKmh} km/h.`;
            }
            // Heuristic 3: Teleportation / GPS Jump (moving > 100m in < 10 seconds)
            else if (timeDiffSeconds < 10 && distMeters > 100) {
                credibilityScore -= 80;
                suspensionReason = "GPS jump detected (teleportation).";
            }
        }
    }

    if (credibilityScore < 50) {
        return res.status(400).json({
            status: "error",
            message: "Aktivitas absensi mencurigakan terdeteksi (mock location / spoofing).",
            details: suspensionReason || `Skor kredibilitas lokasi rendah: ${credibilityScore}`,
            speed_kmh: calculatedSpeedKmh,
            distance_meters: calculatedDistanceMeters
        });
    }

    try {
        await prisma.$executeRaw`
            INSERT INTO absensi (id_user, id_kelas, id_sesi_absensi, type_absensi, koordinat, is_mock_location, "updatedAt")
            VALUES (
              ${id_user},
              ${parseInt(id_kelas)},
              ${sesi.id_sesi_absensi},
              ${sesi.type_absensi}::"TypeAbsensi",
              POINT(${lng}, ${lat}),
              ${isMock},
              NOW()
            )
        `;
    } catch (error) {
        // A parallel request for the same session won the unique index (uq_absensi_user_sesi)
        if (isUniqueViolation(error)) {
            return res.status(409).json({
                status: "error",
                message: ABSENSI_DUPLIKAT_MESSAGE
            });
        }
        throw error;
    }

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
    const { type_absensi, date } = req.query;
    const { page, limit, skip } = clampPagination({ page: req.query.page, limit: req.query.limit ?? 50 });

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

    // Filter by date if provided: the whole Jakarta calendar day ("2026-10-14" = 00:00-23:59:59.999 WIB)
    if (date) {
        const targetDate = new Date(date);
        if (isNaN(targetDate.getTime())) {
            return res.status(400).json({
                status: "error",
                message: "Format tanggal tidak valid"
            });
        }

        const { start, end } = jakartaDayRange(targetDate);
        where.createdAt = {
            gte: start,
            lte: end
        };
    }

    const [absensi, total] = await prisma.$transaction([
        prisma.absensi.findMany({
            where,
            skip,
            take: limit,
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
            page,
            limit,
            totalPages: Math.ceil(total / limit)
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

    const idKelas = parseInt(id);

    // Sessions, enrollments (with their dates) and attendance of the class
    const [sesiList, pesertaList, absensiList] = await Promise.all([
        prisma.sesiAbsensi.findMany({
            where: { id_kelas: idKelas, deletedAt: null },
            select: { id_sesi_absensi: true, mulai: true, selesai: true, status: true }
        }),
        prisma.pesertaKelas.findMany({
            where: { id_kelas: idKelas },
            select: { id_mahasiswa: true, createdAt: true, deletedAt: true }
        }),
        prisma.absensi.findMany({
            where: { id_kelas: idKelas, deletedAt: null },
            select: {
                id_user: true,
                id_sesi_absensi: true,
                type_absensi: true,
                user: { select: { role: true } }
            }
        })
    ]);

    // Only attendance in closed sessions that started on/after the student's enrollment counts
    const now = new Date();
    const sesiById = new Map(sesiList.map(s => [s.id_sesi_absensi, s]));
    const enrolledAtByUser = new Map(pesertaList.map(p => [p.id_mahasiswa, p.createdAt]));
    const countedAbsensi = absensiList.filter(a => {
        const sesi = sesiById.get(a.id_sesi_absensi);
        return !!sesi && isCountableSession(sesi, enrolledAtByUser.get(a.id_user), now);
    });

    const totalPeserta = pesertaList.filter(p => !p.deletedAt).length;
    const totalSesi = sesiList.filter(s => isCountableSession(s, null, now)).length;

    const absensiByType = countedAbsensi.reduce((acc, item) => {
        acc[item.type_absensi] = (acc[item.type_absensi] || 0) + 1;
        return acc;
    }, {});

    // Absensi per mahasiswa
    const absensiPerMahasiswa = new Map();
    countedAbsensi
        .filter(a => a.user?.role === 'MAHASISWA')
        .forEach(a => absensiPerMahasiswa.set(a.id_user, (absensiPerMahasiswa.get(a.id_user) || 0) + 1));
    const totalAbsensiMahasiswa = [...absensiPerMahasiswa.values()].reduce((sum, count) => sum + count, 0);

    res.status(200).json({
        status: "success",
        data: {
            totalPeserta,
            totalSesi,
            totalAbsensi: countedAbsensi.length,
            absensiByType,
            totalMahasiswaAbsensi: absensiPerMahasiswa.size,
            averageAbsensiPerMahasiswa: absensiPerMahasiswa.size > 0
                ? (totalAbsensiMahasiswa / absensiPerMahasiswa.size).toFixed(2)
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
    const { status } = req.query;
    const { page, limit, skip } = clampPagination({ page: req.query.page, limit: req.query.limit ?? 20 });

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
            take: limit,
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
            page,
            limit,
            totalPages: Math.ceil(total / limit)
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

    // 1. Get enrolled classes (unchanged)
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
                    dosen: { select: { id_user: true, nama: true } }
                }
            }
        }
    });

    // 2. Extract all kelas IDs
    const kelasIds = enrolledClasses.map(pk => pk.id_kelas);

    // 3. BULK fetch all sesi for ALL enrolled kelas (1 query instead of N)
    const allSesi = await prisma.sesiAbsensi.findMany({
        where: {
            id_kelas: { in: kelasIds },
            deletedAt: null
        },
        orderBy: { mulai: 'desc' }
    });

    // 4. BULK fetch all user absensi for ALL enrolled kelas (1 query instead of N)
    const allAbsensi = await prisma.absensi.findMany({
        where: {
            id_user,
            id_kelas: { in: kelasIds },
            deletedAt: null
        },
        select: {
            id_sesi_absensi: true,
            id_kelas: true,
            createdAt: true,
            type_absensi: true
        }
    });

    // 5. Group data in-memory (O(N) operations, no DB calls)
    const sesiByKelas = new Map();
    allSesi.forEach(s => {
        if (!sesiByKelas.has(s.id_kelas)) sesiByKelas.set(s.id_kelas, []);
        sesiByKelas.get(s.id_kelas).push(s);
    });

    const absensiByKelas = new Map();
    allAbsensi.forEach(a => {
        if (!absensiByKelas.has(a.id_kelas)) absensiByKelas.set(a.id_kelas, []);
        absensiByKelas.get(a.id_kelas).push(a);
    });

    const now = new Date();

    // 6. Build result (pure in-memory mapping, no async)
    const result = enrolledClasses.map(pk => {
        const kelasSesi = sesiByKelas.get(pk.id_kelas) || [];
        const kelasAbsensi = absensiByKelas.get(pk.id_kelas) || [];

        const absensiMap = new Map();
        kelasAbsensi.forEach(a => {
            absensiMap.set(a.id_sesi_absensi, {
                waktu: a.createdAt,
                type: a.type_absensi
            });
        });

        // Sessions held before the student enrolled are not theirs to attend (keep one they did attend)
        const enrolledAt = pk.createdAt ? new Date(pk.createdAt) : null;
        const relevantSesi = kelasSesi.filter(sesi =>
            !enrolledAt || new Date(sesi.mulai) >= enrolledAt || absensiMap.has(sesi.id_sesi_absensi));

        const sessions = relevantSesi.map(sesi => ({
            id_sesi: sesi.id_sesi_absensi,
            id_sesi_absensi: sesi.id_sesi_absensi,
            tanggal: sesi.mulai,
            mulai: sesi.mulai,
            selesai: sesi.selesai,
            status: sesi.status,
            is_active: sesi.status === true && sesi.mulai <= now && sesi.selesai >= now,
            hadir: absensiMap.has(sesi.id_sesi_absensi),
            type_absensi: absensiMap.get(sesi.id_sesi_absensi)?.type || null,
            waktu_absen: absensiMap.get(sesi.id_sesi_absensi)?.waktu || null
        }));

        // Stats count only closed sessions that started on/after the enrollment
        const countedSesi = relevantSesi.filter(sesi => isCountableSession(sesi, pk.createdAt, now));
        const totalSesi = countedSesi.length;
        const totalHadir = countedSesi.filter(sesi => absensiMap.has(sesi.id_sesi_absensi)).length;

        return {
            kelas: pk.kelas,
            sessions,
            stats: {
                total_sesi: totalSesi,
                total_hadir: totalHadir,
                total_tidak_hadir: totalSesi - totalHadir,
                persentase: totalSesi > 0
                    ? ((totalHadir / totalSesi) * 100).toFixed(1)
                    : 100
            }
        };
    });

    res.status(200).json({ status: "success", data: result });
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
    const idKelas = parseInt(id);

    if (!Number.isInteger(idKelas)) {
        return res.status(400).json({ status: "error", message: "ID kelas tidak valid" });
    }

    const kelas = await prisma.kelas.findFirst({
        where: { id_kelas: idKelas, deletedAt: null }
    });

    if (!kelas) {
        return res.status(404).json({ status: "error", message: "Kelas tidak ditemukan" });
    }

    // DOSEN only for their own class, MAHASISWA only when enrolled, ADMIN for any class
    if (req.user.role === 'DOSEN' && kelas.id_dosen !== req.user.id_user) {
        return res.status(403).json({ status: "error", message: "Anda hanya bisa melihat jadwal pengganti kelas sendiri" });
    }

    if (req.user.role === 'MAHASISWA' && !(await isEnrolledInKelas(idKelas, req.user.id_user))) {
        return res.status(403).json({ status: "error", message: "Anda tidak terdaftar di kelas ini" });
    }

    const where = {
        id_kelas: idKelas,
        deletedAt: null
    };

    if (upcoming === 'true') {
        // From 00:00 WIB today, so an override for later today is still listed
        where.tanggal_asli = { gte: jakartaDayRange().start };
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

    // Get current week range to filter relevant overrides:
    // Monday 00:00 WIB to Sunday 23:59:59.999 WIB of the current Jakarta week
    const { start: startOfWeek, end: endOfWeek } = jakartaWeekRange(new Date());

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
                    targetDayIndex = jakartaWeekday(override.tanggal_ganti);

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

// GET /api/v1/akademik/absensi/ku/stats
exports.getAbsensiKuStats = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const { id_kelas } = req.query;

    const where = { id_user: userId, deletedAt: null };
    if (id_kelas) where.id_kelas = parseInt(id_kelas);

    // Each absensi with its session, plus the enrollment dates, so only attendance in closed
    // sessions that started on/after the enrollment is counted
    const [enrollments, absensiList] = await Promise.all([
        prisma.pesertaKelas.findMany({
            where: { id_mahasiswa: userId, ...(id_kelas && { id_kelas: parseInt(id_kelas) }) },
            select: { id_kelas: true, createdAt: true }
        }),
        prisma.absensi.findMany({
            where,
            select: {
                id_kelas: true,
                type_absensi: true,
                sesiAbsensi: { select: { mulai: true, selesai: true, status: true, deletedAt: true } }
            }
        })
    ]);

    const now = new Date();
    const enrolledAtByKelas = new Map(enrollments.map(e => [e.id_kelas, e.createdAt]));

    // Same shape as the former groupBy: [{ id_kelas, type_absensi, _count: { type_absensi } }]
    const statsByKey = new Map();
    absensiList.forEach(a => {
        if (!a.sesiAbsensi || a.sesiAbsensi.deletedAt) return;
        if (!isCountableSession(a.sesiAbsensi, enrolledAtByKelas.get(a.id_kelas), now)) return;

        const key = `${a.id_kelas}:${a.type_absensi}`;
        if (!statsByKey.has(key)) {
            statsByKey.set(key, { id_kelas: a.id_kelas, type_absensi: a.type_absensi, _count: { type_absensi: 0 } });
        }
        statsByKey.get(key)._count.type_absensi += 1;
    });

    res.status(200).json({ status: 'success', data: [...statsByKey.values()] });
});
