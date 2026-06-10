/*
  Warnings:

  - You are about to alter the column `jam_mulai_ganti` on the `jadwal_pengganti` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - You are about to alter the column `jam_berakhir_ganti` on the `jadwal_pengganti` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - You are about to alter the column `jam_mulai` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - You are about to alter the column `jam_berakhir` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.

*/
-- CreateEnum
CREATE TYPE "StatusAnomali" AS ENUM ('OPEN', 'REVIEWED', 'RESOLVED');

-- AlterEnum
ALTER TYPE "TypeAnomali" ADD VALUE 'POLA_WAKTU_TIDAK_WAJAR';

-- AlterTable
ALTER TABLE "jadwal_pengganti" ALTER COLUMN "jam_mulai_ganti" SET DATA TYPE time,
ALTER COLUMN "jam_berakhir_ganti" SET DATA TYPE time;

-- AlterTable
ALTER TABLE "kelas" ALTER COLUMN "jam_mulai" SET DATA TYPE time,
ALTER COLUMN "jam_berakhir" SET DATA TYPE time;

-- AlterTable
ALTER TABLE "laporan_anomali" ADD COLUMN     "catatan_dosen" TEXT,
ADD COLUMN     "confidence" DOUBLE PRECISION,
ADD COLUMN     "deskripsi" TEXT,
ADD COLUMN     "resolved_at" TIMESTAMP(3),
ADD COLUMN     "status" "StatusAnomali" NOT NULL DEFAULT 'OPEN';
