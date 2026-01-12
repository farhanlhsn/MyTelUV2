/*
  Warnings:

  - You are about to drop the column `face_data_hash` on the `data_biometrik` table. All the data in the column will be lost.
  - You are about to alter the column `jam_mulai` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.
  - You are about to alter the column `jam_berakhir` on the `kelas` table. The data in that column could be lost. The data in that column will be cast from `Time(6)` to `Unsupported("time")`.

*/
-- AlterTable
ALTER TABLE "data_biometrik" DROP COLUMN "face_data_hash",
ADD COLUMN     "face_embedding" DOUBLE PRECISION[],
ADD COLUMN     "photo_url" TEXT;

-- AlterTable
ALTER TABLE "kelas" ALTER COLUMN "jam_mulai" SET DATA TYPE time,
ALTER COLUMN "jam_berakhir" SET DATA TYPE time;
