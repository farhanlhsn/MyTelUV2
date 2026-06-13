-- CreateEnum
CREATE TYPE "ParkingType" AS ENUM ('MASUK', 'KELUAR');

-- AlterTable
ALTER TABLE "SesiAbsensi" ADD COLUMN     "require_face" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "type_absensi" SET DEFAULT 'LOKAL_ABSENSI';

-- AlterTable
ALTER TABLE "absensi" ADD COLUMN     "is_mock_location" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "kelas" ADD COLUMN     "hari" INTEGER,
ADD COLUMN     "id_semester" INTEGER,
ADD COLUMN     "kapasitas" INTEGER NOT NULL DEFAULT 50,
ALTER COLUMN "jam_mulai" SET DATA TYPE time,
ALTER COLUMN "jam_berakhir" SET DATA TYPE time;

-- AlterTable
ALTER TABLE "log_parkir" ADD COLUMN     "confidence" DOUBLE PRECISION,
ADD COLUMN     "face_detected" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "face_image_url" TEXT,
ADD COLUMN     "image_url" TEXT,
ADD COLUMN     "type" "ParkingType" NOT NULL;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "email" TEXT,
ADD COLUMN     "fcm_token" TEXT,
ADD COLUMN     "nim_nip" VARCHAR(20),
ADD COLUMN     "profile_picture" TEXT,
ADD COLUMN     "push_notifications_enabled" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" SERIAL NOT NULL,
    "token" TEXT NOT NULL,
    "id_user" INTEGER NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "password_reset_tokens" (
    "id" SERIAL NOT NULL,
    "token" TEXT NOT NULL,
    "id_user" INTEGER NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "semesters" (
    "id_semester" SERIAL NOT NULL,
    "nama_semester" TEXT NOT NULL,
    "tanggal_mulai" TIMESTAMP(3) NOT NULL,
    "tanggal_selesai" TIMESTAMP(3) NOT NULL,
    "drop_deadline" TIMESTAMP(3) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "semesters_pkey" PRIMARY KEY ("id_semester")
);

-- CreateTable
CREATE TABLE "jadwal_pengganti" (
    "id_jadwal_pengganti" SERIAL NOT NULL,
    "id_kelas" INTEGER NOT NULL,
    "tanggal_asli" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL,
    "tanggal_ganti" TIMESTAMP(3),
    "jam_mulai_ganti" time,
    "jam_berakhir_ganti" time,
    "ruangan_ganti" TEXT,
    "alasan" TEXT NOT NULL,
    "createdBy" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "jadwal_pengganti_pkey" PRIMARY KEY ("id_jadwal_pengganti")
);

-- CreateTable
CREATE TABLE "posts" (
    "id_post" SERIAL NOT NULL,
    "id_user" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "media" TEXT[],
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "location_name" VARCHAR(255),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "posts_pkey" PRIMARY KEY ("id_post")
);

-- CreateTable
CREATE TABLE "post_likes" (
    "id_like" SERIAL NOT NULL,
    "id_post" INTEGER NOT NULL,
    "id_user" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_likes_pkey" PRIMARY KEY ("id_like")
);

-- CreateTable
CREATE TABLE "post_comments" (
    "id_comment" SERIAL NOT NULL,
    "id_post" INTEGER NOT NULL,
    "id_user" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "post_comments_pkey" PRIMARY KEY ("id_comment")
);

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_key" ON "refresh_tokens"("token");

-- CreateIndex
CREATE INDEX "idx_refresh_token" ON "refresh_tokens"("token");

-- CreateIndex
CREATE INDEX "idx_refresh_user" ON "refresh_tokens"("id_user");

-- CreateIndex
CREATE INDEX "idx_refresh_expires" ON "refresh_tokens"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "password_reset_tokens_token_key" ON "password_reset_tokens"("token");

-- CreateIndex
CREATE INDEX "idx_reset_token" ON "password_reset_tokens"("token");

-- CreateIndex
CREATE INDEX "idx_reset_user" ON "password_reset_tokens"("id_user");

-- CreateIndex
CREATE INDEX "idx_jadwal_pengganti_kelas_tgl" ON "jadwal_pengganti"("id_kelas", "tanggal_asli");

-- CreateIndex
CREATE INDEX "idx_jadwal_pengganti_tgl_ganti" ON "jadwal_pengganti"("tanggal_ganti");

-- CreateIndex
CREATE INDEX "idx_post_user_created" ON "posts"("id_user", "createdAt");

-- CreateIndex
CREATE INDEX "idx_post_created" ON "posts"("createdAt");

-- CreateIndex
CREATE INDEX "idx_post_deleted" ON "posts"("deletedAt");

-- CreateIndex
CREATE INDEX "idx_like_post" ON "post_likes"("id_post");

-- CreateIndex
CREATE INDEX "idx_like_user" ON "post_likes"("id_user");

-- CreateIndex
CREATE UNIQUE INDEX "uq_post_user_like" ON "post_likes"("id_post", "id_user");

-- CreateIndex
CREATE INDEX "idx_comment_post_created" ON "post_comments"("id_post", "createdAt");

-- CreateIndex
CREATE INDEX "idx_comment_user" ON "post_comments"("id_user");

-- CreateIndex
CREATE INDEX "idx_comment_deleted" ON "post_comments"("deletedAt");

-- CreateIndex
CREATE INDEX "idx_kelas_hari" ON "kelas"("hari");

-- CreateIndex
CREATE INDEX "idx_kelas_semester" ON "kelas"("id_semester");

-- CreateIndex
CREATE INDEX "idx_log_type" ON "log_parkir"("type");

-- CreateIndex
CREATE UNIQUE INDEX "users_nim_nip_key" ON "users"("nim_nip");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "password_reset_tokens" ADD CONSTRAINT "password_reset_tokens_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kelas" ADD CONSTRAINT "kelas_id_semester_fkey" FOREIGN KEY ("id_semester") REFERENCES "semesters"("id_semester") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "jadwal_pengganti" ADD CONSTRAINT "jadwal_pengganti_id_kelas_fkey" FOREIGN KEY ("id_kelas") REFERENCES "kelas"("id_kelas") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "jadwal_pengganti" ADD CONSTRAINT "jadwal_pengganti_createdBy_fkey" FOREIGN KEY ("createdBy") REFERENCES "users"("id_user") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "posts" ADD CONSTRAINT "posts_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_likes" ADD CONSTRAINT "post_likes_id_post_fkey" FOREIGN KEY ("id_post") REFERENCES "posts"("id_post") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_likes" ADD CONSTRAINT "post_likes_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_comments" ADD CONSTRAINT "post_comments_id_post_fkey" FOREIGN KEY ("id_post") REFERENCES "posts"("id_post") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_comments" ADD CONSTRAINT "post_comments_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "users"("id_user") ON DELETE CASCADE ON UPDATE CASCADE;
