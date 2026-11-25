-- absensi.photo_url is in schema.prisma (selfie of a biometric check-in) but no migration ever
-- created it, so every absensi query failed with "column absensi.photo_url does not exist" on a
-- database built from migrations. IF NOT EXISTS: a database set up with `prisma db push` already
-- has it.
ALTER TABLE "absensi" ADD COLUMN IF NOT EXISTS "photo_url" TEXT;
