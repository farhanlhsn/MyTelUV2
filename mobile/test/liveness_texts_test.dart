import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/liveness_texts.dart';
import 'package:smart_liveliness_detection/smart_liveliness_detection.dart';

void main() {
  test('every challenge has an Indonesian instruction', () {
    expect(livenessInstructionsId.keys.toSet(), ChallengeType.values.toSet());
    expect(livenessInstructionsId.values, everyElement(isNotEmpty));
  });

  test('the messages are the Indonesian ones, not the package defaults', () {
    final LivenessMessages english = LivenessMessages();

    expect(livenessMessagesId.noFaceDetected, 'Wajah tidak terdeteksi');
    expect(livenessMessagesId.initialInstruction, isNot(english.initialInstruction));
    expect(livenessMessagesId.moveCloser, isNot(english.moveCloser));
    expect(livenessMessagesId.processingVerification, isNot(english.processingVerification));
  });

  test('the admin enrolment and the student check both use them', () {
    // Source scan: a LivenessConfig that forgot them would show the package's English texts
    final String admin = readSource('lib/pages/admin/admin_biometrik_page.dart');
    final String student = readSource('lib/pages/biometrik/biometrik_verification_page.dart');

    for (final String source in <String>[admin, student]) {
      expect(source, contains('livenessMessagesId'));
      expect(source, contains('livenessInstructionsId'));
    }
  });
}

String readSource(String path) => File(path).readAsStringSync();
