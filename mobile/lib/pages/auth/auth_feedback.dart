import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/error_helper.dart';

/// The one place an auth page reports a failed [AuthResult] (the controller shows nothing for
/// register / forgot / reset, so the user never gets the same error twice).
///
/// A request that never reached the server offers "Coba Lagi"; an answer from the server (409,
/// invalid token, ...) is shown as-is with the page's own [title].
void showAuthFailure(
  AuthResult result, {
  required String title,
  required VoidCallback onRetry,
}) {
  if (result.isConnectionError) {
    ErrorHelper.showErrorWithRetry(
      result.message,
      title: 'Koneksi Bermasalah',
      onRetry: onRetry,
    );
  } else {
    ErrorHelper.showError(result.message, title: title);
  }
}
