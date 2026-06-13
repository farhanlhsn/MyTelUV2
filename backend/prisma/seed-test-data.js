const { PrismaClient } = require('../generated/prisma');
const bcrypt = require('bcryptjs');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting E2E Testing Seed...');
  
  // Clean up existing test data
  console.log('🧹 Cleaning up database...');
  await prisma.absensi.deleteMany({}).catch(() => {});
  await prisma.sesiAbsensi.deleteMany({}).catch(() => {});
  await prisma.pesertaKelas.deleteMany({}).catch(() => {});
  await prisma.jadwalPengganti.deleteMany({}).catch(() => {});
  await prisma.$executeRawUnsafe('DELETE FROM kelas;').catch(() => {});
  await prisma.matakuliah.deleteMany({}).catch(() => {});
  await prisma.semester.deleteMany({}).catch(() => {});
  await prisma.logParkir.deleteMany({}).catch(() => {});
  await prisma.parkiran.deleteMany({}).catch(() => {});
  await prisma.kendaraan.deleteMany({}).catch(() => {});
  await prisma.dataBiometrik.deleteMany({}).catch(() => {});
  await prisma.user.deleteMany({}).catch(() => {});
  
  // Reset autoincrement sequences to ensure E2E tests have predictable IDs starting from 1
  console.log('🔄 Resetting database sequences...');
  const sequences = [
    'users_id_user_seq',
    'parkiran_id_parkiran_seq',
    'kendaraan_id_kendaraan_seq',
    'kelas_id_kelas_seq',
    'absensi_id_absensi_seq',
    'SesiAbsensi_id_sesi_absensi_seq',
    'matakuliah_id_matakuliah_seq',
    'semesters_id_semester_seq'
  ];
  for (const seq of sequences) {
    await prisma.$executeRawUnsafe(`ALTER SEQUENCE IF EXISTS "${seq}" RESTART WITH 1;`).catch(() => {});
  }

  // 1. Create Users
  const passwordHash = await bcrypt.hash('password123', 10);
  
  const mhs = await prisma.user.create({
    data: {
      nama: 'Test Student Mahasiswa',
      username: 'mhs_test',
      password: passwordHash,
      role: 'MAHASISWA',
      nim_nip: '1301210001',
      email: 'mhs_test@mail.com'
    }
  });
  console.log('✅ Created Mahasiswa');

  const dosen = await prisma.user.create({
    data: {
      nama: 'Test Lecturer Dosen',
      username: 'dosen_test',
      password: passwordHash,
      role: 'DOSEN',
      nim_nip: 'dosen_test_nip',
      email: 'dosen_test@mail.com'
    }
  });
  console.log('✅ Created Dosen');

  const admin = await prisma.user.create({
    data: {
      nama: 'Test Administrator',
      username: 'admin_test',
      password: passwordHash,
      role: 'ADMIN',
      nim_nip: 'admin_test_nip',
      email: 'admin_test@mail.com'
    }
  });
  console.log('✅ Created Admin');

  // 2. Create Biometric Data for Mahasiswa
  // 512-dimension face embedding filled with a dummy face pattern
  const dummyEmbedding = Array(512).fill(0.02);
  await prisma.dataBiometrik.create({
    data: {
      id_user: mhs.id_user,
      face_embedding: dummyEmbedding,
      photo_url: 'https://r2.myteluv2.dev/uploads/test_face.jpg'
    }
  });
  console.log('✅ Created Data Biometrik Mahasiswa');

  // 3. Create Matakuliah & Semester
  const mk = await prisma.matakuliah.create({
    data: {
      nama_matakuliah: 'Sistem Informasi Absensi',
      kode_matakuliah: 'IF301'
    }
  });
  console.log('✅ Created Matakuliah');

  const semester = await prisma.semester.create({
    data: {
      nama_semester: 'Ganjil 2026',
      tanggal_mulai: new Date('2026-01-01'),
      tanggal_selesai: new Date('2026-06-30'),
      drop_deadline: new Date('2026-02-15'),
      is_active: true
    }
  });
  console.log('✅ Created Semester');

  // 4. Create Kelas (using raw SQL because of time/unsupported fields)
  await prisma.$executeRaw`
    INSERT INTO kelas (id_matakuliah, id_dosen, jam_mulai, jam_berakhir, nama_kelas, ruangan, hari, kapasitas, id_semester, "createdAt", "updatedAt")
    VALUES (
      ${mk.id_matakuliah}, 
      ${dosen.id_user}, 
      '08:00:00'::time, 
      '10:30:00'::time, 
      'IF-45-01', 
      'AULA-1', 
      1, 
      40, 
      ${semester.id_semester},
      NOW(), 
      NOW()
    )
  `;
  
  const kelas = await prisma.kelas.findFirst({
    where: { nama_kelas: 'IF-45-01' }
  });
  console.log('✅ Created Kelas:', kelas.id_kelas);

  // 5. Enroll Mahasiswa to Kelas
  await prisma.pesertaKelas.create({
    data: {
      id_mahasiswa: mhs.id_user,
      id_kelas: kelas.id_kelas
    }
  });
  console.log('✅ Enrolled Mahasiswa to Kelas');

  // 6. Create Parking Lot (Parkiran)
  await prisma.$executeRaw`
    INSERT INTO parkiran (nama_parkiran, kapasitas, live_kapasitas, koordinat, "createdAt", "updatedAt")
    VALUES (
      'PARKIRAN_AULA', 
      100, 
      0, 
      point(107.63, -6.97), 
      NOW(), 
      NOW()
    )
  `;
  console.log('✅ Created Parkiran');

  // 7. Register Vehicle (Kendaraan) for Mahasiswa
  const kendaraan = await prisma.kendaraan.create({
    data: {
      plat_nomor: 'B1234XYZ',
      nama_kendaraan: 'Honda Vario Merah',
      id_user: mhs.id_user,
      statusVerif: true,
      status_pengajuan: 'DISETUJUI',
      fotoSTNK: 'stnk.jpg'
    }
  });
  console.log('✅ Created and Verified Vehicle for Mahasiswa:', kendaraan.plat_nomor);

  console.log('🌱 E2E Testing Seed Completed Successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
