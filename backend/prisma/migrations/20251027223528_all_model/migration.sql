/*
  Warnings:

  - You are about to drop the `User` table. If the table is not empty, all the data it contains will be lost.

*/
-- CreateEnum
CREATE TYPE "TypeAbsensi" AS ENUM ('REMOTE_ABSENSI', 'LOKAL_ABSENSI');

-- CreateEnum
CREATE TYPE "TypeAnomali" AS ENUM ('KEHADIRAN_GANDA', 'TIDAK_HADIR_BERULANG');

-- DropTable
DROP TABLE "public"."User";

-- CreateTable
CREATE TABLE "users" (
    "id_user" SERIAL NOT NULL,
    "nama" TEXT NOT NULL,
    "username" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id_user")
);

-- CreateTable
CREATE TABLE "data_biometrik" (
    "id_biometrik" SERIAL NOT NULL,
    "id_user" INTEGER NOT NULL,
    "face_data_hash" VARCHAR(255) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "data_biometrik_pkey" PRIMARY KEY ("id_biometrik")
);

-- CreateTable
CREATE TABLE "kendaraan" (
    "id_kendaraan" SERIAL NOT NULL,
    "plat_nomor" VARCHAR(20) NOT NULL,
    "id_user" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "kendaraan_pkey" PRIMARY KEY ("id_kendaraan")
);

-- CreateTable
CREATE TABLE "parkiran" (
    "id_parkiran" SERIAL NOT NULL,
    "nama_parkiran" VARCHAR(100) NOT NULL,
    "kapasitas" INTEGER NOT NULL,
    "live_kapasitas" INTEGER NOT NULL DEFAULT 0,
    "koordinat" point NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "parkiran_pkey" PRIMARY KEY ("id_parkiran")
);

-- CreateTable
CREATE TABLE "log_parkir" (
    "id_log_parkir" SERIAL NOT NULL,
    "id_kendaraan" INTEGER NOT NULL,
    "id_parkiran" INTEGER NOT NULL,
    "id_user" INTEGER,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "log_parkir_pkey" PRIMARY KEY ("id_log_parkir")
);

-- CreateTable
CREATE TABLE "matakuliah" (
    "id_matakuliah" SERIAL NOT NULL,
    "nama_matakuliah" TEXT NOT NULL,
    "kode_matakuliah" VARCHAR(20) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "matakuliah_pkey" PRIMARY KEY ("id_matakuliah")
);

-- CreateTable
CREATE TABLE "kelas" (
    "id_kelas" SERIAL NOT NULL,
    "id_matakuliah" INTEGER NOT NULL,
    "id_dosen" INTEGER NOT NULL,
    "jam_mulai" time NOT NULL,
    "jam_berakhir" time NOT NULL,
    "nama_kelas" TEXT NOT NULL,
    "ruangan" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "kelas_pkey" PRIMARY KEY ("id_kelas")
);

-- CreateTable
CREATE TABLE "peserta_kelas" (
    "id_mahasiswa" INTEGER NOT NULL,
    "id_kelas" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "pk_pesertakelas" PRIMARY KEY ("id_mahasiswa","id_kelas")
);

-- CreateTable
CREATE TABLE "absensi" (
    "id_absensi" SERIAL NOT NULL,
    "id_user" INTEGER NOT NULL,
    "id_kelas" INTEGER NOT NULL,
    "type_absensi" "TypeAbsensi" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    "koordinat" point NOT NULL,

    CONSTRAINT "absensi_pkey" PRIMARY KEY ("id_absensi")
);

-- CreateTable
CREATE TABLE "laporan_anomali" (
    "id_anomali" SERIAL NOT NULL,
    "id_user" INTEGER NOT NULL,
    "id_kelas" INTEGER,
    "type_anomali" "TypeAnomali" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "laporan_anomali_pkey" PRIMARY KEY ("id_anomali")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE INDEX "idx_user_role" ON "users"("role");

-- CreateIndex
CREATE INDEX "idx_user_created" ON "users"("createdAt");

-- CreateIndex
CREATE INDEX "idx_user_deleted" ON "users"("deletedAt");

-- CreateIndex
CREATE UNIQUE INDEX "data_biometrik_id_user_key" ON "data_biometrik"("id_user");

-- CreateIndex
CREATE INDEX "idx_bio_created" ON "data_biometrik"("createdAt");

-- CreateIndex
CREATE INDEX "idx_bio_deleted" ON "data_biometrik"("deletedAt");

-- CreateIndex
CREATE UNIQUE INDEX "kendaraan_plat_nomor_key" ON "kendaraan"("plat_nomor");

-- CreateIndex
CREATE INDEX "idx_kendaraan_user" ON "kendaraan"("id_user");

-- CreateIndex
CREATE INDEX "idx_kendaraan_created" ON "kendaraan"("createdAt");

-- CreateIndex
CREATE INDEX "idx_kendaraan_deleted" ON "kendaraan"("deletedAt");

-- CreateIndex
CREATE INDEX "idx_parkiran_kapasitas" ON "parkiran"("kapasitas");

-- CreateIndex
CREATE INDEX "idx_parkiran_deleted" ON "parkiran"("deletedAt");

-- CreateIndex
CREATE INDEX "idx_parkiran_loc" ON "parkiran" USING GIST ("koordinat");

-- CreateIndex
CREATE UNIQUE INDEX "uq_parkiran_nama" ON "parkiran"("nama_parkiran");

-- CreateIndex
CREATE INDEX "idx_log_kendaraan_ts" ON "log_parkir"("id_kendaraan", "timestamp");

-- CreateIndex
CREATE INDEX "idx_log_parkiran_ts" ON "log_parkir"("id_parkiran", "timestamp");

-- CreateIndex
CREATE INDEX "idx_log_user_ts" ON "log_parkir"("id_user", "timestamp");

-- CreateIndex
CREATE INDEX "idx_log_ts" ON "log_parkir"("timestamp");

-- CreateIndex
CREATE UNIQUE INDEX "matakuliah_kode_matakuliah_key" ON "matakuliah"("kode_matakuliah");

-- CreateIndex
CREATE INDEX "idx_mk_nama" ON "matakuliah"("nama_matakuliah");

-- CreateIndex
CREATE INDEX "idx_mk_deleted" ON "matakuliah"("deletedAt");

-- CreateIndex
CREATE INDEX "idx_kelas_mk_dosen" ON "kelas"("id_matakuliah", "id_dosen");

-- CreateIndex
CREATE INDEX "idx_kelas_ruangan" ON "kelas"("ruangan");

-- CreateIndex
CREATE INDEX "idx_kelas_waktu" ON "kelas"("jam_mulai", "jam_berakhir");

-- CreateIndex
CREATE INDEX "idx_kelas_deleted" ON "kelas"("deletedAt");

-- CreateIndex
CREATE INDEX "idx_peserta_kelas" ON "peserta_kelas"("id_kelas", "deletedAt");

-- CreateIndex
CREATE INDEX "idx_peserta_mahasiswa" ON "peserta_kelas"("id_mahasiswa", "deletedAt");

-- CreateIndex
CREATE INDEX "idx_absensi_user_ts" ON "absensi"("id_user", "createdAt");

-- CreateIndex
CREATE INDEX "idx_absensi_kelas_ts" ON "absensi"("id_kelas", "createdAt");

-- CreateIndex
CREATE INDEX "idx_absensi_type" ON "absensi"("type_absensi");

-- CreateIndex
CREATE INDEX "idx_absensi_deleted" ON "absensi"("deletedAt");

-- CreateIndex
CREATE INDEX "idx_absensi_created" ON "absensi"("createdAt");

-- CreateIndex
CREATE INDEX "idx_absensi_loc" ON "absensi" USING GIST ("koordinat");

-- CreateIndex
CREATE INDEX "idx_anomali_user_type_ts" ON "laporan_anomali"("id_user", "type_anomali", "createdAt");

-- CreateIndex
CREATE INDEX "idx_anomali_kelas_ts" ON "laporan_anomali"("id_kelas", "createdAt");

-- CreateIndex
CREATE INDEX "idx_anomali_deleted" ON "laporan_anomali"("deletedAt");

-- AddForeignKey
ALTER TABLE "data_biometrik" ADD CONSTRAINT "data_biometrik_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kendaraan" ADD CONSTRAINT "kendaraan_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "log_parkir" ADD CONSTRAINT "log_parkir_id_kendaraan_fkey" FOREIGN KEY ("id_kendaraan") REFERENCES "kendaraan"("id_kendaraan") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "log_parkir" ADD CONSTRAINT "log_parkir_id_parkiran_fkey" FOREIGN KEY ("id_parkiran") REFERENCES "parkiran"("id_parkiran") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "log_parkir" ADD CONSTRAINT "log_parkir_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kelas" ADD CONSTRAINT "kelas_id_matakuliah_fkey" FOREIGN KEY ("id_matakuliah") REFERENCES "matakuliah"("id_matakuliah") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kelas" ADD CONSTRAINT "kelas_id_dosen_fkey" FOREIGN KEY ("id_dosen") REFERENCES "users"("id_user") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "peserta_kelas" ADD CONSTRAINT "peserta_kelas_id_mahasiswa_fkey" FOREIGN KEY ("id_mahasiswa") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "peserta_kelas" ADD CONSTRAINT "peserta_kelas_id_kelas_fkey" FOREIGN KEY ("id_kelas") REFERENCES "kelas"("id_kelas") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "absensi" ADD CONSTRAINT "absensi_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "absensi" ADD CONSTRAINT "absensi_id_kelas_fkey" FOREIGN KEY ("id_kelas") REFERENCES "kelas"("id_kelas") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "laporan_anomali" ADD CONSTRAINT "laporan_anomali_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "laporan_anomali" ADD CONSTRAINT "laporan_anomali_id_kelas_fkey" FOREIGN KEY ("id_kelas") REFERENCES "kelas"("id_kelas") ON DELETE SET NULL ON UPDATE CASCADE;
