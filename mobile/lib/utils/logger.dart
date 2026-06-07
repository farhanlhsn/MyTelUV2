import 'package:flutter/foundation.dart';

/// Debug-only logger. Will not print in release or profile builds.
void debugLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
