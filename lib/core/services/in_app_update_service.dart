import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service that checks for Google Play Store in-app updates.
///
/// Uses the official Play Core In-App Updates API to:
/// - Check if a new app version is available on the Play Store.
/// - Trigger an **immediate** update flow (full-screen Play Store dialog) when found.
///   This is the most reliable mode — it cannot be skipped and doesn't depend
///   on ScaffoldMessenger surviving screen navigation.
///
/// This only works on physical Android devices installed from the Play Store.
/// On emulators or non-Play devices it gracefully no-ops.
class InAppUpdateService {
  InAppUpdateService._();
  static final InAppUpdateService instance = InAppUpdateService._();

  /// Check for an available update and start an immediate update flow if one is found.
  /// Call this BEFORE navigating away from the splash screen so the context is still valid.
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (!context.mounted) return;

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await _startImmediateUpdate();
      }
    } catch (e) {
      // Silently swallow — update checks should never crash the app.
      // Common causes: device not installed from Play Store, emulator, or
      // Play Core not available on the device.
      debugPrint('[InAppUpdateService] Update check failed: $e');
    }
  }

  Future<void> _startImmediateUpdate() async {
    try {
      // Immediate update shows a full-screen Play Store dialog — the user
      // MUST update or close the app. This is the most reliable mode and
      // doesn't require a ScaffoldMessenger or active BuildContext after navigation.
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('[InAppUpdateService] Immediate update failed: $e');
    }
  }
}
