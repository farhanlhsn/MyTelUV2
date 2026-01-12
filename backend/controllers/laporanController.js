const PDFDocument = require('pdfkit-table');
const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma'); // Use shared instance

// ==========================================
// HELPER: Validate ID Parameter
// ==========================================
const validateId = (id, fieldName = 'ID') => {
    const parsed = parseInt(id, 10);
    if (isNaN(parsed) || parsed <= 0) {
        const error = new Error(`${fieldName} tidak valid`);
        error.statusCode = 400;
        throw error;
    }
    return parsed;
};

// ==========================================
// HELPER: Get Status Style for Table Rows
// ==========================================
const getStatusStyle = (status) => {
    if (status?.includes('TIDAK HADIR') || status === '✗') {
        return { font: 'Helvetica-Bold', color: COLORS.danger };
    } else if (status?.includes('HADIR') || status === '✓') {
        return { font: 'Helvetica-Bold', color: COLORS.success };
    }
    return { font: 'Helvetica', color: COLORS.dark };
};

// ==========================================
// DESIGN CONSTANTS
// ==========================================
const COLORS = {
    primary: '#B71C1C',       // Tel-U Red (darker, more professional)
    primaryLight: '#FFEBEE',  // Light red background
    secondary: '#1A237E',     // Deep blue
    success: '#1B5E20',       // Dark green for HADIR
    successLight: '#E8F5E9', // Light green background
    danger: '#B71C1C',        // Dark red for TIDAK HADIR
    dangerLight: '#FFEBEE',   // Light red background
    dark: '#212121',          // Almost black
    gray: '#616161',          // Medium gray
    lightGray: '#F5F5F5',     // Background gray
    white: '#FFFFFF',
    border: '#E0E0E0'
};

// ==========================================
// HELPER: Add Modern Header
// ==========================================
const addHeader = (doc, title, subtitle, isLandscape = false) => {
    const logoPath = path.join(__dirname, '../assets/telyu.png');
    const margin = 40;
    const startY = 35;
    const pageWidth = doc.page.width;

    // Header background with gradient effect (simulated with rectangle)
    doc.save();
    doc.rect(0, 0, pageWidth, 110).fill('#FAFAFA');
    doc.restore();

    // Logo and University Name
    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, margin, startY, { width: 55 });

        // University name with better typography
        doc.font('Helvetica-Bold')
            .fontSize(18)
            .fillColor(COLORS.primary)
            .text('Telkom University', margin + 70, startY + 8);

        doc.font('Helvetica')
            .fontSize(10)
            .fillColor(COLORS.gray)
            .text('Digital Campus • Excellence in Education', margin + 70, startY + 28);
    } else {
        doc.font('Helvetica-Bold')
            .fontSize(18)
            .fillColor(COLORS.primary)
            .text('Telkom University', margin, startY);
    }

    // Red accent line (thicker and more prominent)
    const lineY = 105;
    doc.save();
    doc.moveTo(margin, lineY)
        .lineTo(pageWidth - margin, lineY)
        .strokeColor(COLORS.primary)
        .lineWidth(3)
        .stroke();
    doc.restore();

    // Title section with background
    const titleY = lineY + 15;
    doc.save();
    doc.rect(margin, titleY, pageWidth - (margin * 2), 50)
        .fill(COLORS.primaryLight);
    doc.restore();

    // Border for title section
    doc.save();
    doc.rect(margin, titleY, pageWidth - (margin * 2), 50)
        .strokeColor(COLORS.border)
        .lineWidth(1)
        .stroke();
    doc.restore();

    // Title text
    doc.font('Helvetica-Bold')
        .fontSize(14)
        .fillColor(COLORS.dark)
        .text(title, margin + 15, titleY + 12);

    // Subtitle
    if (subtitle) {
        doc.font('Helvetica')
            .fontSize(10)
            .fillColor(COLORS.gray)
            .text(subtitle, margin + 15, titleY + 30);
    }

    doc.y = titleY + 65; // Set Y position for content
};

// ==========================================
// HELPER: Add Footer
// ==========================================
const addFooter = (doc, isLandscape = false) => {
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    const margin = 40;
    const footerY = pageHeight - 40;

    // Footer line
    doc.save();
    doc.moveTo(margin, footerY - 10)
        .lineTo(pageWidth - margin, footerY - 10)
        .strokeColor(COLORS.border)
        .lineWidth(0.5)
        .stroke();
    doc.restore();

    // Footer text
    const timestamp = new Date().toLocaleString('id-ID', {
        year: 'numeric', month: 'long', day: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });

    doc.font('Helvetica')
        .fontSize(8)
        .fillColor(COLORS.gray);

    doc.text(`Dicetak pada: ${timestamp}`, margin, footerY);
    doc.text('Sistem Akademik MyTelUV', pageWidth - margin - 120, footerY);
};

// ==========================================
// HELPER: Draw Summary Stats Box
// ==========================================
const addSummaryBox = (doc, stats, isLandscape = false) => {
    const margin = 40;
    const pageWidth = doc.page.width;
    const boxWidth = isLandscape ? 180 : 150;
    const boxHeight = 50;
    const boxY = doc.y;
    const spacing = 15;

    const boxes = [
        { label: 'Total Mahasiswa', value: stats.total, color: COLORS.secondary },
        { label: 'Hadir', value: stats.hadir, color: COLORS.success },
        { label: 'Tidak Hadir', value: stats.tidakHadir, color: COLORS.danger }
    ];

    const totalWidth = (boxWidth * boxes.length) + (spacing * (boxes.length - 1));
    let startX = (pageWidth - totalWidth) / 2;

    boxes.forEach((box, index) => {
        const x = startX + (index * (boxWidth + spacing));

        // Box background
        doc.save();
        doc.roundedRect(x, boxY, boxWidth, boxHeight, 5)
            .fill(COLORS.lightGray);
        doc.restore();

        // Box border
        doc.save();
        doc.roundedRect(x, boxY, boxWidth, boxHeight, 5)
            .strokeColor(COLORS.border)
            .lineWidth(1)
            .stroke();
        doc.restore();

        // Value
        doc.font('Helvetica-Bold')
            .fontSize(18)
            .fillColor(box.color)
            .text(box.value.toString(), x, boxY + 10, { width: boxWidth, align: 'center' });

        // Label
        doc.font('Helvetica')
            .fontSize(9)
            .fillColor(COLORS.gray)
            .text(box.label, x, boxY + 32, { width: boxWidth, align: 'center' });
    });

    doc.y = boxY + boxHeight + 20;
};

// ==========================================
// 1. Laporan Per Sesi (Portrait)
// ==========================================
exports.generateLaporanSesiPdf = asyncHandler(async (req, res) => {
    const sesiId = validateId(req.params.id, 'ID Sesi');
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // 1. Fetch Session Data
    const sesi = await prisma.sesiAbsensi.findUnique({
        where: { id_sesi_absensi: sesiId },
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

    // 2. Fetch students and attendance in parallel
    const [peserta, absensi] = await Promise.all([
        prisma.pesertaKelas.findMany({
            where: { id_kelas: sesi.id_kelas, deletedAt: null },
            include: { mahasiswa: true },
            orderBy: { mahasiswa: { username: 'asc' } }
        }),
        prisma.absensi.findMany({
            where: { id_sesi_absensi: sesiId, deletedAt: null }
        })
    ]);

    // Map existing attendance
    const attendanceMap = new Map();
    absensi.forEach(a => {
        attendanceMap.set(a.id_user, a);
    });

    // Calculate stats
    let hadirCount = 0;
    peserta.forEach(p => {
        if (attendanceMap.has(p.id_mahasiswa)) hadirCount++;
    });

    // 2. Generate PDF
    const doc = new PDFDocument({ margin: 40, size: 'A4' });

    // Stream response
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=Sesi_${sesi.kelas.nama_kelas}_${new Date(sesi.mulai).toISOString().split('T')[0]}.pdf`);

    doc.pipe(res);

    // Header
    const formattedDate = new Date(sesi.mulai).toLocaleDateString('id-ID', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit'
    });

    addHeader(doc, 'Laporan Kehadiran Sesi', `${sesi.kelas.matakuliah.nama_matakuliah} (${sesi.kelas.nama_kelas}) - ${formattedDate}`);

    // Summary Stats Box
    addSummaryBox(doc, {
        total: peserta.length,
        hadir: hadirCount,
        tidakHadir: peserta.length - hadirCount
    });

    // Table Data
    const tableData = peserta.map((p, index) => {
        const record = attendanceMap.get(p.id_mahasiswa);
        const status = record ? '✓ HADIR' : '✗ TIDAK HADIR';
        const waktu = record ? new Date(record.createdAt).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : '-';

        return [
            (index + 1).toString(),
            p.mahasiswa.username, // NIM
            p.mahasiswa.nama,
            status,
            waktu
        ];
    });

    // Table with styled header
    const table = {
        title: "",
        headers: ["No", "NIM", "Nama Mahasiswa", "Status", "Waktu Absen"],
        rows: tableData
    };

    await doc.table(table, {
        width: 515,
        x: 40,
        columnsSize: [35, 100, 180, 110, 90],
        divider: {
            header: { disabled: false, width: 1, opacity: 1 },
            horizontal: { disabled: false, width: 0.5, opacity: 0.5 }
        },
        padding: [5, 5, 5, 5],
        prepareHeader: () => doc.font("Helvetica-Bold").fontSize(10).fillColor(COLORS.dark),
        prepareRow: (row, i, j, rect, rowData) => {
            doc.font("Helvetica").fontSize(10).fillColor(COLORS.dark);

            // Status Column Formatting
            if (i === 3) {
                if (rowData[3] && rowData[3].includes('TIDAK HADIR')) {
                    doc.font("Helvetica-Bold").fillColor(COLORS.danger);
                } else if (rowData[3]) {
                    doc.font("Helvetica-Bold").fillColor(COLORS.success);
                }
            }
        }
    });

    // Footer
    addFooter(doc);

    doc.end();
});

// ==========================================
// 2. Laporan Rekap Kelas (Landscape)
// ==========================================
exports.generateLaporanKelasPdf = asyncHandler(async (req, res) => {
    const kelasId = validateId(req.params.id, 'ID Kelas');
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // 1. Fetch Class Data
    const kelas = await prisma.kelas.findUnique({
        where: { id_kelas: kelasId },
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

    // 2. Fetch sessions, students, and attendance in parallel
    const [sessions, peserta, allAbsensi] = await Promise.all([
        prisma.sesiAbsensi.findMany({
            where: { id_kelas: kelasId, deletedAt: null },
            orderBy: { mulai: 'asc' }
        }),
        prisma.pesertaKelas.findMany({
            where: { id_kelas: kelasId, deletedAt: null },
            include: { mahasiswa: true },
            orderBy: { mahasiswa: { username: 'asc' } }
        }),
        prisma.absensi.findMany({
            where: { id_kelas: kelasId, deletedAt: null }
        })
    ]);

    // Matrix Processing
    const absensiMap = new Map(); // key: "userId_sesiId" -> true
    allAbsensi.forEach(a => {
        absensiMap.set(`${a.id_user}_${a.id_sesi_absensi}`, true);
    });

    // 5. Generate PDF
    const doc = new PDFDocument({ margin: 40, size: 'A4', layout: 'landscape' });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=Rekap_${kelas.nama_kelas}.pdf`);

    doc.pipe(res);

    addHeader(doc, 'Rekap Kehadiran Kelas', `${kelas.matakuliah.nama_matakuliah} (${kelas.nama_kelas}) - Pengajar: ${kelas.dosen.nama}`, true);

    // Build headers with session dates
    const headers = ["No", "NIM", "Nama"];

    // Calculate column width for sessions dynamically
    const sessionColWidth = sessions.length > 10 ? 25 : 30;

    sessions.forEach((s) => {
        const dateStr = new Date(s.mulai).toLocaleDateString('id-ID', { day: 'numeric', month: 'numeric' });
        headers.push(dateStr);
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
            row.push(isHadir ? "✓" : "✗"); // ✓ = Hadir, ✗ = Absen
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

    // Calculate column sizes
    const columnSizes = [30, 80, 140];
    sessions.forEach(() => columnSizes.push(sessionColWidth));
    columnSizes.push(40, 40);

    await doc.table(table, {
        width: 760,
        x: 40,
        columnsSize: columnSizes,
        divider: {
            header: { disabled: false, width: 1, opacity: 1 },
            horizontal: { disabled: false, width: 0.5, opacity: 0.5 }
        },
        padding: [3, 3, 3, 3],
        prepareHeader: () => doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.dark),
        prepareRow: (row, i, j, rect, rowData) => {
            doc.font("Helvetica").fontSize(8).fillColor(COLORS.dark);

            // Conditional Coloring for ✓/✗
            if (i >= 3 && i < headers.length - 2) {
                const val = rowData[i];
                if (val === '✓') {
                    doc.fillColor(COLORS.success).font("Helvetica-Bold");
                } else if (val === '✗') {
                    doc.fillColor(COLORS.danger).font("Helvetica-Bold");
                }
            }

            // Style for percentage column
            if (i === headers.length - 1) {
                const percentVal = parseInt(rowData[i]);
                if (percentVal >= 80) {
                    doc.fillColor(COLORS.success).font("Helvetica-Bold");
                } else if (percentVal >= 50) {
                    doc.fillColor('#FF8F00').font("Helvetica-Bold"); // Orange/Warning
                } else {
                    doc.fillColor(COLORS.danger).font("Helvetica-Bold");
                }
            }
        }
    });

    // Add Legend
    const legendY = doc.y + 15;
    doc.font('Helvetica').fontSize(9).fillColor(COLORS.gray);
    doc.text('Keterangan: ', 40, legendY);
    doc.font('Helvetica-Bold').fillColor(COLORS.success).text('✓ = Hadir', 110, legendY);
    doc.font('Helvetica-Bold').fillColor(COLORS.danger).text('✗ = Tidak Hadir', 170, legendY);

    // Footer
    addFooter(doc, true);

    doc.end();
});

// ==========================================
// 3. Laporan Sesi - Excel Export
// ==========================================
exports.generateLaporanSesiExcel = asyncHandler(async (req, res) => {
    const sesiId = validateId(req.params.id, 'ID Sesi');
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // Fetch Session Data
    const sesi = await prisma.sesiAbsensi.findUnique({
        where: { id_sesi_absensi: sesiId },
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

    if (userRole === 'DOSEN' && sesi.kelas.id_dosen !== userId) {
        return res.status(403).json({ status: "error", message: "Anda tidak memiliki akses" });
    }

    // Fetch students and attendance in parallel
    const [peserta, absensi] = await Promise.all([
        prisma.pesertaKelas.findMany({
            where: { id_kelas: sesi.id_kelas, deletedAt: null },
            include: { mahasiswa: true },
            orderBy: { mahasiswa: { username: 'asc' } }
        }),
        prisma.absensi.findMany({
            where: { id_sesi_absensi: sesiId, deletedAt: null }
        })
    ]);

    const attendanceMap = new Map();
    absensi.forEach(a => attendanceMap.set(a.id_user, a));

    // Create Excel Workbook
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'MyTelUV - Sistem Akademik';
    workbook.created = new Date();

    const worksheet = workbook.addWorksheet('Kehadiran Sesi');

    // Header styles
    const headerFill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFB71C1C' } };
    const headerFont = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11 };
    const borderStyle = { style: 'thin', color: { argb: 'FFE0E0E0' } };

    // Title Row
    worksheet.mergeCells('A1:E1');
    const titleCell = worksheet.getCell('A1');
    titleCell.value = `Laporan Kehadiran - ${sesi.kelas.matakuliah.nama_matakuliah} (${sesi.kelas.nama_kelas})`;
    titleCell.font = { bold: true, size: 14, color: { argb: 'FFB71C1C' } };

    // Subtitle Row
    worksheet.mergeCells('A2:E2');
    const subtitleCell = worksheet.getCell('A2');
    const formattedDate = new Date(sesi.mulai).toLocaleDateString('id-ID', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit'
    });
    subtitleCell.value = `Tanggal: ${formattedDate}`;
    subtitleCell.font = { size: 11, color: { argb: 'FF616161' } };

    // Empty row
    worksheet.addRow([]);

    // Header row
    const headerRow = worksheet.addRow(['No', 'NIM', 'Nama Mahasiswa', 'Status', 'Waktu Absen']);
    headerRow.font = headerFont;
    headerRow.eachCell((cell) => {
        cell.fill = headerFill;
        cell.border = { top: borderStyle, left: borderStyle, bottom: borderStyle, right: borderStyle };
        cell.alignment = { vertical: 'middle', horizontal: 'center' };
    });

    // Data rows
    peserta.forEach((p, index) => {
        const record = attendanceMap.get(p.id_mahasiswa);
        const status = record ? 'HADIR' : 'TIDAK HADIR';
        const waktu = record ? new Date(record.createdAt).toLocaleTimeString('id-ID', {
            hour: '2-digit', minute: '2-digit', second: '2-digit'
        }) : '-';

        const row = worksheet.addRow([
            index + 1,
            p.mahasiswa.username,
            p.mahasiswa.nama,
            status,
            waktu
        ]);

        // Style status cell
        const statusCell = row.getCell(4);
        if (status === 'HADIR') {
            statusCell.font = { bold: true, color: { argb: 'FF1B5E20' } };
            statusCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8F5E9' } };
        } else {
            statusCell.font = { bold: true, color: { argb: 'FFB71C1C' } };
            statusCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFEBEE' } };
        }

        row.eachCell((cell) => {
            cell.border = { top: borderStyle, left: borderStyle, bottom: borderStyle, right: borderStyle };
        });
    });

    // Set column widths
    worksheet.columns = [
        { width: 6 },   // No
        { width: 15 },  // NIM
        { width: 30 },  // Nama
        { width: 15 },  // Status
        { width: 15 }   // Waktu
    ];

    // Summary row
    worksheet.addRow([]);
    const hadirCount = absensi.length;
    const summary = worksheet.addRow(['', '', `Total: ${peserta.length} Mahasiswa`, `Hadir: ${hadirCount}`, `Tidak Hadir: ${peserta.length - hadirCount}`]);
    summary.font = { bold: true };

    // Set response headers
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=Sesi_${sesi.kelas.nama_kelas}_${new Date(sesi.mulai).toISOString().split('T')[0]}.xlsx`);

    await workbook.xlsx.write(res);
});

// ==========================================
// 4. Laporan Rekap Kelas - Excel Export
// ==========================================
exports.generateLaporanKelasExcel = asyncHandler(async (req, res) => {
    const kelasId = validateId(req.params.id, 'ID Kelas');
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // Fetch Class Data
    const kelas = await prisma.kelas.findUnique({
        where: { id_kelas: kelasId },
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

    // Fetch sessions, students, and attendance in parallel
    const [sessions, peserta, allAbsensi] = await Promise.all([
        prisma.sesiAbsensi.findMany({
            where: { id_kelas: kelasId, deletedAt: null },
            orderBy: { mulai: 'asc' }
        }),
        prisma.pesertaKelas.findMany({
            where: { id_kelas: kelasId, deletedAt: null },
            include: { mahasiswa: true },
            orderBy: { mahasiswa: { username: 'asc' } }
        }),
        prisma.absensi.findMany({
            where: { id_kelas: kelasId, deletedAt: null }
        })
    ]);

    const absensiMap = new Map();
    allAbsensi.forEach(a => absensiMap.set(`${a.id_user}_${a.id_sesi_absensi}`, true));

    // Create Excel Workbook
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'MyTelUV - Sistem Akademik';
    workbook.created = new Date();

    const worksheet = workbook.addWorksheet('Rekap Kehadiran');

    // Styles
    const headerFill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFB71C1C' } };
    const headerFont = { bold: true, color: { argb: 'FFFFFFFF' }, size: 10 };
    const borderStyle = { style: 'thin', color: { argb: 'FFE0E0E0' } };

    // Title Row
    worksheet.mergeCells(1, 1, 1, 5 + sessions.length);
    const titleCell = worksheet.getCell('A1');
    titleCell.value = `Rekap Kehadiran Kelas - ${kelas.matakuliah.nama_matakuliah} (${kelas.nama_kelas})`;
    titleCell.font = { bold: true, size: 14, color: { argb: 'FFB71C1C' } };

    // Subtitle Row
    worksheet.mergeCells(2, 1, 2, 5 + sessions.length);
    const subtitleCell = worksheet.getCell('A2');
    subtitleCell.value = `Pengajar: ${kelas.dosen.nama} | Total Sesi: ${sessions.length}`;
    subtitleCell.font = { size: 11, color: { argb: 'FF616161' } };

    // Empty row
    worksheet.addRow([]);

    // Build headers
    const headers = ['No', 'NIM', 'Nama'];
    sessions.forEach((s) => {
        const dateStr = new Date(s.mulai).toLocaleDateString('id-ID', { day: 'numeric', month: 'numeric' });
        headers.push(dateStr);
    });
    headers.push('Total', '%');

    // Header row
    const headerRow = worksheet.addRow(headers);
    headerRow.font = headerFont;
    headerRow.eachCell((cell) => {
        cell.fill = headerFill;
        cell.border = { top: borderStyle, left: borderStyle, bottom: borderStyle, right: borderStyle };
        cell.alignment = { vertical: 'middle', horizontal: 'center' };
    });

    // Data rows
    peserta.forEach((p, idx) => {
        const rowData = [idx + 1, p.mahasiswa.username, p.mahasiswa.nama];

        let hadirCount = 0;
        sessions.forEach(s => {
            const isHadir = absensiMap.has(`${p.id_mahasiswa}_${s.id_sesi_absensi}`);
            if (isHadir) hadirCount++;
            rowData.push(isHadir ? '✓' : '✗');
        });

        const percentage = sessions.length > 0 ? Math.round((hadirCount / sessions.length) * 100) : 0;
        rowData.push(hadirCount, `${percentage}%`);

        const row = worksheet.addRow(rowData);

        // Style attendance cells
        for (let i = 4; i <= 3 + sessions.length; i++) {
            const cell = row.getCell(i);
            if (cell.value === '✓') {
                cell.font = { bold: true, color: { argb: 'FF1B5E20' } };
            } else if (cell.value === '✗') {
                cell.font = { bold: true, color: { argb: 'FFB71C1C' } };
            }
            cell.alignment = { horizontal: 'center' };
        }

        // Style percentage cell
        const percentCell = row.getCell(4 + sessions.length);
        if (percentage >= 80) {
            percentCell.font = { bold: true, color: { argb: 'FF1B5E20' } };
            percentCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8F5E9' } };
        } else if (percentage >= 50) {
            percentCell.font = { bold: true, color: { argb: 'FFFF8F00' } };
            percentCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFF3E0' } };
        } else {
            percentCell.font = { bold: true, color: { argb: 'FFB71C1C' } };
            percentCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFEBEE' } };
        }

        row.eachCell((cell) => {
            cell.border = { top: borderStyle, left: borderStyle, bottom: borderStyle, right: borderStyle };
        });
    });

    // Set column widths
    const columns = [
        { width: 5 },   // No
        { width: 15 },  // NIM
        { width: 25 }   // Nama
    ];
    sessions.forEach(() => columns.push({ width: 6 }));
    columns.push({ width: 6 }, { width: 6 });
    worksheet.columns = columns;

    // Set response headers
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=Rekap_${kelas.nama_kelas}.xlsx`);

    await workbook.xlsx.write(res);
});
