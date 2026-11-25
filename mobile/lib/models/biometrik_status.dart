/// Own biometric status: `data` of GET /api/v1/biometrik/status.
class BiometrikStatus {
  /// An active (not soft-deleted) face is enrolled for the logged-in user.
  final bool terdaftar;

  /// Last update of the enrolled face (UTC); null when nothing is enrolled.
  final DateTime? diperbarui;

  const BiometrikStatus({required this.terdaftar, this.diperbarui});

  /// Null when [json] has no boolean `terdaftar`: such a response must not be read as
  /// "not registered".
  static BiometrikStatus? fromJson(dynamic json) {
    if (json is! Map) return null;
    final terdaftar = json['terdaftar'];
    if (terdaftar is! bool) return null;

    final diperbarui = json['diperbarui'];
    return BiometrikStatus(
      terdaftar: terdaftar,
      diperbarui: diperbarui is String
          ? DateTime.tryParse(diperbarui)?.toUtc()
          : null,
    );
  }
}
