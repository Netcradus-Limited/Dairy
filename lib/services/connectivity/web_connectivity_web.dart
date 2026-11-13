// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

/// Web implementation querying `window.navigator.onLine`.
bool? getBrowserOnlineStatus() {
  try {
    return html.window.navigator.onLine ?? true;
  } catch (_) {
    return true;
  }
}

/// Web implementation listening to browser `online` and `offline` DOM events.
Stream<bool>? getBrowserConnectivityStream() {
  try {
    late StreamController<bool> controller;
    StreamSubscription<html.Event>? onlineSub;
    StreamSubscription<html.Event>? offlineSub;

    controller = StreamController<bool>.broadcast(
      onListen: () {
        onlineSub = html.window.onOnline.listen((_) {
          if (!controller.isClosed) controller.add(true);
        });
        offlineSub = html.window.onOffline.listen((_) {
          if (!controller.isClosed) controller.add(false);
        });
      },
      onCancel: () {
        onlineSub?.cancel();
        offlineSub?.cancel();
      },
    );

    return controller.stream;
  } catch (_) {
    return null;
  }
}
