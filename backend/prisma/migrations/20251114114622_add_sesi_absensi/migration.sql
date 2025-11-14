/*
  Warnings:

  - You are about to alter the column `jam_mulai` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - You are about to alter the column `jam_berakhir` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - Added the required column `id_sesi_absensi` to the `absensi` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "absensi" ADD COLUMN     "id_sesi_absensi" INTEGER NOT NULL;

-- AlterTable
ALTER TABLE "kelas" ALTER COLUMN "jam_mulai" SET DATA TYPE time,
ALTER COLUMN "jam_berakhir" SET DATA TYPE time;

-- CreateTable
CREATE TABLE "SesiAbsensi" (
    "id_sesi_absensi" SERIAL NOT NULL,
    "id_kelas" INTEGER NOT NULL,
    "type_absensi" "TypeAbsensi" NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "radius_meter" INTEGER,
    "mulai" TIMESTAMP(3) NOT NULL,
    "selesai" TIMESTAMP(3) NOT NULL,
    "status" BOOLEAN NOT NULL DEFAULT true,
    "createdBy" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "SesiAbsensi_pkey" PRIMARY KEY ("id_sesi_absensi")
);

-- AddForeignKey
ALTER TABLE "SesiAbsensi" ADD CONSTRAINT "SesiAbsensi_id_kelas_fkey" FOREIGN KEY ("id_kelas") REFERENCES "kelas"("id_kelas") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "absensi" ADD CONSTRAINT "absensi_id_sesi_absensi_fkey" FOREIGN KEY ("id_sesi_absensi") REFERENCES "SesiAbsensi"("id_sesi_absensi") ON DELETE RESTRICT ON UPDATE CASCADE;
