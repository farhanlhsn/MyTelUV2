-- Attendance status (B8): HADIR/TELAT = present, IZIN/SAKIT = excused, ALPHA = absent.
-- Existing rows are check-ins, so they become HADIR.

-- CreateEnum
CREATE TYPE "StatusKehadiran" AS ENUM ('HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA');

-- AlterTable
-- diubah_oleh: id_user of the DOSEN/ADMIN who last set the status by hand (deliberately no foreign key).
-- koordinat: a record entered by a DOSEN/ADMIN (e.g. while the face service is down) has no check-in
-- location, so it is stored as NULL instead of a made-up point.
ALTER TABLE "absensi" ADD COLUMN "status" "StatusKehadiran" NOT NULL DEFAULT 'HADIR',
ADD COLUMN "keterangan" TEXT,
ADD COLUMN "diubah_oleh" INTEGER,
ALTER COLUMN "koordinat" DROP NOT NULL;
