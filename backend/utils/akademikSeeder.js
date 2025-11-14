const prisma = require('../utils/prisma');
const bcrypt = require('bcrypt');
const path = require('path');
require("dotenv").config({ path: path.resolve(__dirname, "../../.env") });

// Data dummy
const matakuliahData = [
  { nama: 'Pemrograman Web', kode: 'IF301' },
  { nama: 'Basis Data', kode: 'IF302' },
  { nama: 'Algoritma dan Struktur Data', kode: 'IF201' },
  { nama: 'Pemrograman Mobile', kode: 'IF303' },
  { nama: 'Jaringan Komputer', kode: 'IF304' },
  { nama: 'Sistem Operasi', kode: 'IF305' },
  { nama: 'Kecerdasan Buatan', kode: 'IF401' },
  { nama: 'Machine Learning', kode: 'IF402' }
];

const kelasSchedules = [
  { jam_mulai: '08:00:00', jam_berakhir: '10:00:00', nama_suffix: 'A', ruangan: 'Lab 301' },
  { jam_mulai: '10:00:00', jam_berakhir: '12:00:00', nama_suffix: 'B', ruangan: 'Lab 302' },
  { jam_mulai: '13:00:00', jam_berakhir: '15:00:00', nama_suffix: 'C', ruangan: 'Lab 303' },
  { jam_mulai: '15:00:00', jam_berakhir: '17:00:00', nama_suffix: 'D', ruangan: 'Ruang 201' }
];

async function seedAkademik() {
  console.log('🌱 Starting akademik seeder...\n');

  try {
    // ======================================================
    // 1. Create ADMIN user
    // ======================================================
    console.log('👤 Creating users...');
    const hashedPassword = await bcrypt.hash('password123', 10);

    const admin = await prisma.user.upsert({
      where: { username: 'admin' },
      update: {},
      create: {
        nama: 'Admin User',
        username: 'admin',
        password: hashedPassword,
        role: 'ADMIN'
      }
    });
    console.log('✅ Admin created:', admin.username);

    // ======================================================
    // 2. Create DOSEN users
    // ======================================================
    const dosenNames = [
      { nama: 'Dr. John Doe', username: 'john.doe' },
      { nama: 'Dr. Jane Smith', username: 'jane.smith' },
      { nama: 'Prof. Ahmad Hassan', username: 'ahmad.hassan' },
      { nama: 'Dr. Siti Nurhaliza', username: 'siti.nurhaliza' },
      { nama: 'Prof. Budi Santoso', username: 'budi.santoso' }
    ];

    const dosenList = [];
    for (const dosen of dosenNames) {
      const created = await prisma.user.upsert({
        where: { username: dosen.username },
        update: {},
        create: {
          nama: dosen.nama,
          username: dosen.username,
          password: hashedPassword,
          role: 'DOSEN'
        }
      });
      dosenList.push(created);
      console.log('✅ Dosen created:', created.username);
    }

    // ======================================================
    // 3. Create MAHASISWA users
    // ======================================================
    const mahasiswaList = [];
    for (let i = 1; i <= 20; i++) {
      const mahasiswa = await prisma.user.upsert({
        where: { username: `mahasiswa${i}` },
        update: {},
        create: {
          nama: `Mahasiswa ${i}`,
          username: `mahasiswa${i}`,
          password: hashedPassword,
          role: 'MAHASISWA'
        }
      });
      mahasiswaList.push(mahasiswa);
    }
    console.log(`✅ Created ${mahasiswaList.length} mahasiswa\n`);

    // ======================================================
    // 4. Create Matakuliah
    // ======================================================
    console.log('📚 Creating matakuliah...');
    const matakuliahList = [];
    for (const mk of matakuliahData) {
      const matakuliah = await prisma.matakuliah.upsert({
        where: { kode_matakuliah: mk.kode },
        update: {},
        create: {
          nama_matakuliah: mk.nama,
          kode_matakuliah: mk.kode
        }
      });
      matakuliahList.push(matakuliah);
      console.log(`✅ Matakuliah: ${mk.kode} - ${mk.nama}`);
    }
    console.log('');

    // ======================================================
    // 5. Create Kelas
    //    - tiap matakuliah punya 1–2 kelas dengan jadwal berbeda
    // ======================================================
    console.log('🏫 Creating kelas...');
    const kelasList = [];

    for (let i = 0; i < matakuliahList.length; i++) {
      const matakuliah = matakuliahList[i];
      const numKelas = Math.random() > 0.5 ? 2 : 1; // Random 1 or 2 kelas per matakuliah

      for (let j = 0; j < numKelas; j++) {
        const schedule = kelasSchedules[j];
        const dosen = dosenList[i % dosenList.length]; // Round-robin assign dosen

        // Insert kelas via raw query (karena jam_mulai/jam_berakhir tipe time)
        await prisma.$executeRaw`
          INSERT INTO kelas (
            id_matakuliah,
            id_dosen,
            jam_mulai,
            jam_berakhir,
            nama_kelas,
            ruangan,
            "createdAt",
            "updatedAt"
          )
          VALUES (
            ${matakuliah.id_matakuliah},
            ${dosen.id_user},
            ${schedule.jam_mulai}::time,
            ${schedule.jam_berakhir}::time,
            ${matakuliah.kode_matakuliah + '-' + schedule.nama_suffix},
            ${schedule.ruangan},
            NOW(),
            NOW()
          )
          ON CONFLICT DO NOTHING
        `;

        const kelas = await prisma.kelas.findFirst({
          where: {
            id_matakuliah: matakuliah.id_matakuliah,
            nama_kelas: matakuliah.kode_matakuliah + '-' + schedule.nama_suffix
          }
        });

        if (kelas) {
          kelasList.push(kelas);
          console.log(
            `✅ Kelas: ${kelas.nama_kelas} - ${schedule.ruangan} (${schedule.jam_mulai}-${schedule.jam_berakhir})`
          );
        }
      }
    }
    console.log('');

    // ======================================================
    // 6. Enroll mahasiswa ke kelas (3–5 kelas random per mahasiswa)
    // ======================================================
    console.log('👥 Enrolling mahasiswa to kelas...');
    let totalEnrollments = 0;

    for (const mahasiswa of mahasiswaList) {
    const numKelas = Math.floor(Math.random() * 3) + 3; // 3–5 kelas
    const selectedKelas = [];

    // Pilih kelas random unik
    while (selectedKelas.length < numKelas && selectedKelas.length < kelasList.length) {
        const randomKelas = kelasList[Math.floor(Math.random() * kelasList.length)];
        if (!selectedKelas.find(k => k.id_kelas === randomKelas.id_kelas)) {
        selectedKelas.push(randomKelas);
        }
    }

    const dataEnroll = selectedKelas.map(kelas => ({
        id_mahasiswa: mahasiswa.id_user,
        id_kelas: kelas.id_kelas,
    }));

    if (dataEnroll.length > 0) {
        const result = await prisma.pesertaKelas.createMany({
        data: dataEnroll,
        skipDuplicates: true, // ⬅️ kunci penting
        });

        // `result.count` = jumlah row yang bener-bener berhasil diinsert
        totalEnrollments += result.count;
    }
    }

    console.log(`✅ Enrollments inserted: ${totalEnrollments}\n`);


    // ======================================================
    // 7. Create SesiAbsensi + Absensi records (5 hari ke belakang)
    // ======================================================
    console.log('🕒 Creating sesi absensi & absensi records...');

    // Ambil semua peserta kelas, dikelompokkan per kelas
    const allPeserta = await prisma.pesertaKelas.findMany({
      where: { deletedAt: null },
      include: {
        mahasiswa: true,
        kelas: true
      }
    });

    // Map: id_kelas -> array peserta
    const pesertaByKelas = {};
    for (const peserta of allPeserta) {
      if (!pesertaByKelas[peserta.id_kelas]) {
        pesertaByKelas[peserta.id_kelas] = [];
      }
      pesertaByKelas[peserta.id_kelas].push(peserta);
    }

    let totalSesi = 0;
    let totalAbsensi = 0;

    // Simulasi 5 hari ke belakang
    for (let dayOffset = 0; dayOffset < 5; dayOffset++) {
      const targetDate = new Date();
      targetDate.setDate(targetDate.getDate() - dayOffset);
      targetDate.setHours(9, 0, 0, 0); // jam mulai default 09:00

      const endDate = new Date(targetDate);
      endDate.setHours(targetDate.getHours() + 2); // durasi 2 jam

      for (const kelas of kelasList) {
        const pesertaKelas = pesertaByKelas[kelas.id_kelas] || [];
        if (pesertaKelas.length === 0) continue;

        // random tipe sesi: lokal atau remote
        const typeAbsensi = Math.random() > 0.5 ? 'LOKAL_ABSENSI' : 'REMOTE_ABSENSI';

        // kalau REMOTE_ABSENSI, set koordinat sekitar kampus (Jakarta dummy)
        let latitude = null;
        let longitude = null;
        let radius = null;

        if (typeAbsensi === 'REMOTE_ABSENSI') {
          latitude = -6.2088 + (Math.random() - 0.5) * 0.01;
          longitude = 106.8456 + (Math.random() - 0.5) * 0.01;
          radius = 200; // 200 meter
        }

        // Cari dosen pengampu sebagai createdBy
        const dosenPengampu = dosenList.find(d => d.id_user === kelas.id_dosen) || dosenList[0];

        // Buat sesi absensi
        const sesi = await prisma.sesiAbsensi.create({
          data: {
            id_kelas: kelas.id_kelas,
            type_absensi: typeAbsensi,
            latitude,
            longitude,
            radius_meter: radius,
            mulai: targetDate,
            selesai: endDate,
            status: true, // terbuka (untuk data historis ini tidak terlalu ngaruh)
            createdBy: dosenPengampu.id_user,
          }
        });
        totalSesi++;

        // Random 60–80% kehadiran
        const numAbsensi = Math.floor(pesertaKelas.length * (0.6 + Math.random() * 0.2));
        const selectedPeserta = [...pesertaKelas]
          .sort(() => Math.random() - 0.5)
          .slice(0, numAbsensi);

        for (const peserta of selectedPeserta) {
          const lat = latitude !== null
            ? latitude + (Math.random() - 0.5) * 0.002
            : -6.2088 + (Math.random() - 0.5) * 0.01;
          const lng = longitude !== null
            ? longitude + (Math.random() - 0.5) * 0.002
            : 106.8456 + (Math.random() - 0.5) * 0.01;

          try {
            // Insert absensi: pakai POINT(lng, lat) untuk tipe point
            await prisma.$executeRaw`
              INSERT INTO absensi (
                id_user,
                id_kelas,
                id_sesi_absensi,
                type_absensi,
                koordinat,
                "createdAt",
                "updatedAt"
              )
              VALUES (
                ${peserta.id_mahasiswa},
                ${kelas.id_kelas},
                ${sesi.id_sesi_absensi},
                ${typeAbsensi}::"TypeAbsensi",
                POINT(${lng}, ${lat}),
                ${targetDate},
                ${targetDate}
              )
            `;
            totalAbsensi++;
          } catch (error) {
            // kalau ada duplikat atau error lain, skip aja
          }
        }
      }
    }

    console.log(`✅ Created ${totalSesi} sesi absensi`);
    console.log(`✅ Created ${totalAbsensi} absensi records\n`);

    // ======================================================
    // 8. Summary
    // ======================================================
    console.log('📊 SEEDING SUMMARY:');
    console.log('==================');
    console.log(`✅ Matakuliah : ${matakuliahList.length}`);
    console.log(`✅ Kelas      : ${kelasList.length}`);
    console.log(`✅ Dosen      : ${dosenList.length}`);
    console.log(`✅ Mahasiswa  : ${mahasiswaList.length}`);
    console.log(`✅ Enrollments: ${totalEnrollments}`);
    console.log(`✅ SesiAbsensi: ${totalSesi}`);
    console.log(`✅ Absensi    : ${totalAbsensi}`);
    console.log('\n🎉 Seeding completed successfully!\n');

    console.log('🔑 TEST CREDENTIALS:');
    console.log('==================');
    console.log('Admin:');
    console.log('  Username: admin');
    console.log('  Password: password123\n');
    console.log('Dosen (example):');
    console.log('  Username: john.doe');
    console.log('  Password: password123\n');
    console.log('Mahasiswa (example):');
    console.log('  Username: mahasiswa1');
    console.log('  Password: password123\n');

  } catch (error) {
    console.error('❌ Error seeding data:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run seeder
seedAkademik()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
