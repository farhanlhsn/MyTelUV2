import 'package:flutter/material.dart';

/// `08:05`: the `HH:MM` the server expects for `jam_mulai_ganti` / `jam_berakhir_ganti`.
String formatJamHHmm(TimeOfDay time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Error text for the new class times of a "ganti jadwal", or null when they are fine. Both or
/// neither must be chosen (neither keeps the original times) and the end must be after the start.
String? validateJamGanti(TimeOfDay? mulai, TimeOfDay? berakhir) {
  if (mulai == null && berakhir == null) return null;
  if (mulai == null) return 'Pilih jam mulai';
  if (berakhir == null) return 'Pilih jam berakhir';

  final int startMinutes = mulai.hour * 60 + mulai.minute;
  final int endMinutes = berakhir.hour * 60 + berakhir.minute;
  if (endMinutes <= startMinutes) return 'Jam berakhir harus setelah jam mulai';
  return null;
}
