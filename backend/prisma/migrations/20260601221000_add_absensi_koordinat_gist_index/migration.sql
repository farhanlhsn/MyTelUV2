-- Create spatial GiST index on absensi.koordinat for fast geofence / radius lookup
CREATE INDEX IF NOT EXISTS idx_absensi_koordinat_gist ON absensi USING gist (koordinat);
