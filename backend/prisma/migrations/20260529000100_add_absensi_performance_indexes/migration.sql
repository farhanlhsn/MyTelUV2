CREATE INDEX "idx_sesi_absensi_active_lookup"
ON "SesiAbsensi"("id_kelas", "status", "mulai", "selesai", "deletedAt");

CREATE INDEX "idx_sesi_absensi_creator_ts"
ON "SesiAbsensi"("createdBy", "createdAt");

CREATE INDEX "idx_sesi_absensi_deleted"
ON "SesiAbsensi"("deletedAt");

CREATE UNIQUE INDEX "uq_absensi_user_sesi"
ON "absensi"("id_user", "id_sesi_absensi");

CREATE INDEX "idx_absensi_sesi_deleted"
ON "absensi"("id_sesi_absensi", "deletedAt");
