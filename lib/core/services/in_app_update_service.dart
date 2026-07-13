import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service that checks for Google Play Store in-app updates.
///
/// Uses the official Play Core In-App Updates API to:
/// - Silently check if a new app version is available on the Play Store.
/// - Trigger a **flexible** (non-blocking) update flow when found.
/// - Show a snackbar prompting the user to restart once the update is downloaded.
///
/// This only works on physical Android devices connected to the Play Store.
/// On iOS or non-Play devices it gracefully no-ops.
class InAppUpdateService {
  InAppUpdateService._();
  static final InAppUpdateService instance = InAppUpdateService._();

  /// Check for an available update and start a flexible update flow if one is found.
  /// Call this once per app session (e.g., from the splash screen).
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (!context.mounted) return;

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await _startFlexibleUpdate(context);
      }
    } catch (e) {
      // Silently swallow — update checks should never crash the app.
      // Common causes: device not connected to Play Store, emulator, or
      // Play Core not available on the device.
      debugPrint('[InAppUpdateService] Update check failed: $e');
    }
  }

  Future<void> _startFlexibleUpdate(BuildContext context) async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();

      if (!context.mounted) return;

      if (result == AppUpdateResult.success) {
        // Download complete — prompt the user to apply the update
        _showRestartSnackBar(context);
      }
    } catch (e) {
      debugPrint('[InAppUpdateService] Flexible update failed: $e');
    }
  }

  void _showRestartSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '🎉 Update downloaded! Restart to apply the latest version.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF064E3B),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Restart',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('[InAppUpdateService] Complete update failed: $e');
            }
          },
        ),
      ),
    );
  }
}
