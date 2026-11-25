-- Data migration: store existing plates in the canonical form the API uses from now on
-- (upper case, letters and digits only; see backend/utils/plate.js normalizePlate).
--
-- A plate is only rewritten when its normalised value is unique among the normalised values of ALL
-- rows (soft-deleted rows included: the unique index on "plat_nomor" covers them). Rows whose
-- normalised value would collide with another row, and plates with no letters or digits at all, are
-- left exactly as they are, so this migration can never fail on "kendaraan_plat_nomor_key".
WITH "normalized" AS (
    SELECT
        "id_kendaraan",
        "plat_nomor" AS "old_plat",
        upper(regexp_replace("plat_nomor", '[^A-Za-z0-9]', '', 'g')) AS "new_plat"
    FROM "kendaraan"
)
UPDATE "kendaraan" AS k
SET "plat_nomor" = n."new_plat"
FROM "normalized" AS n
WHERE k."id_kendaraan" = n."id_kendaraan"
  AND n."new_plat" <> ''
  AND n."new_plat" <> n."old_plat"
  AND NOT EXISTS (
      SELECT 1
      FROM "normalized" AS o
      WHERE o."id_kendaraan" <> n."id_kendaraan"
        AND o."new_plat" = n."new_plat"
  );
