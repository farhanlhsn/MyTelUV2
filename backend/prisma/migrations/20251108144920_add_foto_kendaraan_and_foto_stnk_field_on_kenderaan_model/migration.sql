/*
  Warnings:

  - You are about to alter the column `jam_mulai` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - You are about to alter the column `jam_berakhir` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - Added the required column `fotoSTNK` to the `kendaraan` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "kelas" ALTER COLUMN "jam_mulai" SET DATA TYPE time,
ALTER COLUMN "jam_berakhir" SET DATA TYPE time;

-- AlterTable
ALTER TABLE "kendaraan" ADD COLUMN     "fotoKendaraan" TEXT[],
ADD COLUMN     "fotoSTNK" TEXT NOT NULL;
