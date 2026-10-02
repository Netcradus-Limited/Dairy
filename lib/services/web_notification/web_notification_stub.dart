/// Stub implementation for non-web platforms and Dart VM unit tests.
void showWebNotification({
  required String title,
  required String body,
  String? icon,
  String? tag,
  Map<String, dynamic>? data,
  void Function()? onClick,
}) {
  // No-op on Android, iOS, macOS, Windows, Linux, and test runners
}
