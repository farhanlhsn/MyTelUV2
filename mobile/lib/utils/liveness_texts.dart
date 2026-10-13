import 'package:smart_liveliness_detection/smart_liveliness_detection.dart';

/// What the liveness screen tells the person in front of the camera, in Indonesian. The package's own
/// defaults are English, so every `LivenessConfig` of the app (student check, admin enrolment) passes
/// these.
const LivenessMessages livenessMessagesId = LivenessMessages(
  moveFartherAway: 'Jauhkan wajah dari kamera',
  moveCloser: 'Dekatkan wajah ke kamera',
  moveRight: 'Geser wajah ke kanan',
  moveLeft: 'Geser wajah ke kiri',
  moveUp: 'Geser wajah ke atas',
  moveDown: 'Geser wajah ke bawah',
  perfectHoldStill: 'Sempurna! Tahan posisi Anda',
  noFaceDetected: 'Wajah tidak terdeteksi',
  errorCheckingFacePosition: 'Gagal mendeteksi posisi wajah',
  initializing: 'Menyiapkan...',
  initializingCamera: 'Menghubungkan kamera...',
  errorInitializingCamera: 'Kamera gagal dimulai. Silakan mulai ulang aplikasi.',
  initialInstruction: 'Posisikan wajah Anda di dalam oval',
  poorLighting: 'Pindah ke area yang lebih terang',
  processingVerification: 'Memproses verifikasi...',
  verificationComplete: 'Verifikasi wajah selesai!',
  spoofingDetected: 'Terdeteksi potensi manipulasi (spoofing).',
  errorProcessing: 'Terjadi kesalahan pemrosesan',
);

/// The instruction shown for each challenge the person has to perform.
const Map<ChallengeType, String> livenessInstructionsId = <ChallengeType, String>{
  ChallengeType.blink: 'Silakan berkedip',
  ChallengeType.smile: 'Silakan tersenyum',
  ChallengeType.turnRight: 'Tengok ke kanan',
  ChallengeType.turnLeft: 'Tengok ke kiri',
  ChallengeType.nod: 'Anggukkan kepala',
  ChallengeType.tiltUp: 'Dongakkan kepala',
  ChallengeType.tiltDown: 'Tundukkan kepala',
  ChallengeType.zoom: 'Dekatkan wajah ke kamera',
  ChallengeType.normal: 'Posisikan wajah lurus ke depan',
};
