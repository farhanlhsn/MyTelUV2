/// Outcome of an auth call (register / forgot password / reset password / change password).
///
/// The controller reports it and shows nothing itself: the page owns the feedback, so an error is
/// never shown twice. [message] is the Indonesian text to show (the server's own message when it
/// sent one).
class AuthResult {
  final bool success;
  final String message;

  /// The request never reached the server (offline, timeout) as opposed to the server saying no.
  final bool isConnectionError;

  const AuthResult.success([this.message = ''])
    : success = true,
      isConnectionError = false;

  const AuthResult.failure(this.message, {this.isConnectionError = false})
    : success = false;
}
