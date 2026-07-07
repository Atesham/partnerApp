import 'package:flutter/foundation.dart';

/// Release-safe debug logging wrapper.
///
/// In debug mode, delegates to [debugPrint]. In release/profile builds,
/// this is a complete no-op — no string interpolation or I/O overhead.
void debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
