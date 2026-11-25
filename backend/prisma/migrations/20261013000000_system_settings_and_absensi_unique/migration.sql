-- CreateTable
-- Idempotent: environments that created the table by hand (the former scratch_create_table.js)
-- already have it, with the same constraint names Prisma uses.
CREATE TABLE IF NOT EXISTS "system_settings" (
    "id" SERIAL NOT NULL,
    "key" VARCHAR(255) NOT NULL,
    "value" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "system_settings_key_key" ON "system_settings"("key");

-- CreateIndex
-- Already created by 20260529000100_add_absensi_performance_indexes; it is now also declared in
-- schema.prisma (@@unique ... map: "uq_absensi_user_sesi"), so this is a no-op where it exists.
CREATE UNIQUE INDEX IF NOT EXISTS "uq_absensi_user_sesi" ON "absensi"("id_user", "id_sesi_absensi");
