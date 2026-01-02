const PDFDocument = require('pdfkit-table');
const path = require('path');
const fs = require('fs');
const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma'); // Use shared instance

// Helper to add header with logo and red accent
const addHeader = (doc, title, subtitle) => {
    const logoPath = path.join(__dirname, '../assets/telyu.png');
    const startY = 45;

    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, 50, startY, { width: 50 });

        doc.font('Helvetica-Bold')
            .fontSize(16)
            .fillColor('#333333')
            .text('Telkom University', 110, startY);

        doc.font('Helvetica-Bold')
            .fontSize(14)
            .fillColor('#000000')
            .text(title, 110, startY + 20);

        if (subtitle) {
            doc.font('Helvetica')
                .fontSize(11)
                .fillColor('#555555')
                .text(subtitle, 110, startY + 40);
        }
    } else {
        doc.font('Helvetica-Bold')
            .fontSize(16)
            .text(title, 50, startY);

        if (subtitle) {
            doc.fontSize(12)
                .text(subtitle, 50, startY + 25);
        }
    }

    // Red Accent Line
    const lineY = startY + 65;
    doc.moveTo(50, lineY)
        .lineTo(doc.page.width - 50, lineY)
        .strokeColor('#E63946') // Tel-U Red
        .lineWidth(2)
        .stroke();

    doc.y = lineY + 20; // Set Y position for content
};

// ==========================================
// 1. Laporan Per Sesi (Portrait)
// ==========================================
exports.generateLaporanSesiPdf = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // 1. Fetch Data
    const sesi = await prisma.sesiAbsensi.findUnique({
        where: { id_sesi_absensi: parseInt(id) },
        include: {
            kelas: {
                include: {
                    matakuliah: true,
                    dosen: true
                }
            }
        }
    });

    if (!sesi) {
        return res.status(404).json({ status: "error", message: "Sesi tidak ditemukan" });
    }

    // Authorization
    if (userRole === 'DOSEN' && sesi.kelas.id_dosen !== userId) {
        return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses" });
    }

    // Get all students enrolled
    const peserta = await prisma.pesertaKelas.findMany({
        where: { id_kelas: sesi.id_kelas, deletedAt: null },
        include: { mahasiswa: true },
        orderBy: { mahasiswa: { username: 'asc' } }
    });

    // Get attendance records for this session
    const absensi = await prisma.absensi.findMany({
        where: { id_sesi_absensi: parseInt(id), deletedAt: null }
    });

    // Map existing attendance
    const attendanceMap = new Map();
    absensi.forEach(a => {
        attendanceMap.set(a.id_user, a);
    });

    // 2. Generate PDF
    const doc = new PDFDocument({ margin: 30, size: 'A4' });

    // Stream response
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=Laporan_Sesi_${sesi.kelas.nama_kelas}_${new Date(sesi.mulai).toISOString().split('T')[0]}.pdf`);

    doc.pipe(res);

    // Header
    const formattedDate = new Date(sesi.mulai).toLocaleDateString('id-ID', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit'
    });

    addHeader(doc, 'Laporan Kehadiran Sesi', `${sesi.kelas.matakuliah.nama_matakuliah} (${sesi.kelas.nama_kelas}) - ${formattedDate}`);

    // Table Data
    const tableData = peserta.map((p, index) => {
        const record = attendanceMap.get(p.id_mahasiswa);
        const status = record ? 'HADIR' : 'TIDAK HADIR';
        const waktu = record ? new Date(record.createdAt).toLocaleTimeString('id-ID') : '-';

        return [
            (index + 1).toString(),
            p.mahasiswa.username, // NIM
            p.mahasiswa.nama,
            status,
            waktu
        ];
    });

    // Table
    const table = {
        title: "",
        headers: ["No", "NIM", "Nama", "Status", "Waktu Absen"],
        rows: tableData
    };

    await doc.table(table, {
        width: 535, // A4 (595) - 60 margin = 535
        prepareHeader: () => doc.font("Helvetica-Bold").fontSize(10).fillColor('black'),
        prepareRow: (row, i, j, rect, rowData) => {
            // Zebra Striping background
            if (j % 2 === 0) {
                doc.save();
                doc.fillColor('#f8f9fa');
                doc.rect(rect.x, rect.y, rect.width, rect.height).fill();
                doc.restore();
            }

            doc.font("Helvetica").fontSize(10).fillColor('black');

            // Status Column Formatting
            if (i === 3) {
                if (rowData[3] === 'TIDAK HADIR') {
                    doc.font("Helvetica-Bold").fillColor('#D32F2F'); // Red
                } else {
                    doc.font("Helvetica-Bold").fillColor('#2E7D32'); // Green
                }
            }
        }
    });

    doc.end();
});

// ==========================================
// 2. Laporan Rekap Kelas (Landscape)
// ==========================================
exports.generateLaporanKelasPdf = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // 1. Fetch Class Data
    const kelas = await prisma.kelas.findUnique({
        where: { id_kelas: parseInt(id) },
        include: {
            matakuliah: true,
            dosen: true
        }
    });

    if (!kelas) {
        return res.status(404).json({ status: "error", message: "Kelas tidak ditemukan" });
    }

    if (userRole === 'DOSEN' && kelas.id_dosen !== userId) {
        return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses" });
    }

    // 2. Fetch All Sessions
    const sessions = await prisma.sesiAbsensi.findMany({
        where: { id_kelas: parseInt(id), deletedAt: null },
        orderBy: { mulai: 'asc' }
    });

    // 3. Fetch All Students
    const peserta = await prisma.pesertaKelas.findMany({
        where: { id_kelas: parseInt(id), deletedAt: null },
        include: { mahasiswa: true },
        orderBy: { mahasiswa: { username: 'asc' } }
    });

    // 4. Fetch All Absensi
    const allAbsensi = await prisma.absensi.findMany({
        where: { id_kelas: parseInt(id), deletedAt: null }
    });

    // Matrix Processing
    const absensiMap = new Map(); // key: "userId_sesiId" -> true
    allAbsensi.forEach(a => {
        absensiMap.set(`${a.id_user}_${a.id_sesi_absensi}`, true);
    });

    // 5. Generate PDF
    const doc = new PDFDocument({ margin: 30, size: 'A4', layout: 'landscape' });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=Rekap_Absensi_${kelas.nama_kelas}.pdf`);

    doc.pipe(res);

    addHeader(doc, 'Rekap Kehadiran Kelas', `${kelas.matakuliah.nama_matakuliah} (${kelas.nama_kelas}) - ${kelas.dosen.nama}`);

    const headers = ["No", "NIM", "Nama"];
    sessions.forEach((s, i) => {
        const dateStr = new Date(s.mulai).toLocaleDateString('id-ID', { day: 'numeric', month: 'numeric' });
        headers.push(`${i + 1}\n${dateStr}`);
    });
    headers.push("Total");
    headers.push("%");

    const rows = peserta.map((p, idx) => {
        const row = [
            (idx + 1).toString(),
            p.mahasiswa.username,
            p.mahasiswa.nama
        ];

        let hadirCount = 0;
        sessions.forEach(s => {
            const isHadir = absensiMap.has(`${p.id_mahasiswa}_${s.id_sesi_absensi}`);
            if (isHadir) hadirCount++;
            row.push(isHadir ? "H" : "A"); // H = Hadir, A = Absen
        });

        row.push(hadirCount.toString());
        const percentage = sessions.length > 0 ? ((hadirCount / sessions.length) * 100).toFixed(0) + '%' : '0%';
        row.push(percentage);

        return row;
    });

    const table = {
        title: "",
        headers: headers,
        rows: rows
    };

    await doc.table(table, {
        width: 780,
        datas: rows,
        headers: headers,
        prepareHeader: () => doc.font("Helvetica-Bold").fontSize(8).fillColor('black'),
        prepareRow: (row, i, j, rect, rowData) => {

            // Zebra Striping
            if (j % 2 === 0) {
                doc.save();
                doc.fillColor('#f8f9fa');
                doc.rect(rect.x, rect.y, rect.width, rect.height).fill();
                doc.restore();
            }

            doc.font("Helvetica").fontSize(8).fillColor('black');

            // Conditional Coloring for H/A
            // i is column index
            if (i >= 3 && i < headers.length - 2) {
                const val = rowData[i];
                if (val === 'H') {
                    doc.fillColor('#2E7D32').font("Helvetica-Bold"); // Green
                } else if (val === 'A') {
                    doc.fillColor('#D32F2F').font("Helvetica-Bold"); // Red
                }
            }
        }
    });

    doc.end();
});
