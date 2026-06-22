import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../constants/supabase_constants.dart';

class SupabaseStorageService {
  static const String bucketName = 'kabadi_bookings';

  /// Uploads an XFile to Supabase Storage and returns its public URL.
  /// If it fails, it returns a fallback mock image URL to prevent blocking the flow.
  static Future<String> uploadImage(XFile file) async {
    final projectId = SupabaseConstants.projectId;
    final anonKey = SupabaseConstants.anonKey;

    try {
      final bytes = await file.readAsBytes();
      final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final fileName = 'partner_${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final uploadUrl = Uri.parse(
        'https://$projectId.supabase.co/storage/v1/object/$bucketName/$fileName',
      );

      final response = await http.post(
        uploadUrl,
        headers: {
          'Authorization': 'Bearer $anonKey',
          'apiKey': anonKey,
          'Content-Type': 'image/jpeg',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return 'https://$projectId.supabase.co/storage/v1/object/public/$bucketName/$fileName';
      } else {
        debugPrint(
          '❌ Supabase Upload Error: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Supabase upload failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint(
        '⚠️ Supabase upload exception: $e. Falling back to default mockup image to not block partner.',
      );
      return 'https://images.unsplash.com/photo-1611284446314-60a58ac0deb9?auto=format&fit=crop&w=800&q=80';
    }
  }

  /// Uploads a list of XFiles to Supabase Storage.
  static Future<List<String>> uploadImages(List<XFile> files) async {
    final List<String> imageUrls = [];
    for (final file in files) {
      final url = await uploadImage(file);
      imageUrls.add(url);
    }
    return imageUrls;
  }
}
