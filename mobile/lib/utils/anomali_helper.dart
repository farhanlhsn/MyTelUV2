/// `warnings` of the anomaly analyze response (e.g. "Layanan analisis pola waktu tidak tersedia"
/// when the AI service is down): the analysis still succeeded, one rule was skipped.
List<String> parseAnomaliWarnings(dynamic body) {
  if (body is! Map) return <String>[];
  final raw = body['warnings'];
  if (raw is! List) return <String>[];

  final warnings = <String>[];
  for (final item in raw) {
    if (item is! String) continue;
    final text = item.trim();
    if (text.isNotEmpty && !warnings.contains(text)) warnings.add(text);
  }
  return warnings;
}

String joinWarnings(List<String> warnings) => warnings.join('\n');

/// Result line of "Scan Ulang" over every class.
String scanSummaryMessage({required int total, required int failed}) {
  if (failed <= 0) return 'Scan selesai untuk $total kelas';
  if (failed >= total) return 'Scan gagal untuk semua kelas ($total)';
  return 'Scan selesai, $failed dari $total kelas gagal dipindai';
}
