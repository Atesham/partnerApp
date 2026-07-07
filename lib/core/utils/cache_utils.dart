import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class CacheUtils {
  /// Encodes a Map or List containing Firestore Timestamps to a JSON string.
  static String encode(dynamic data) {
    return jsonEncode(data, toEncodable: (val) {
      if (val is Timestamp) {
        return {
          '_type': 'timestamp',
          'seconds': val.seconds,
          'nanoseconds': val.nanoseconds,
        };
      }
      if (val is DateTime) {
        return {
          '_type': 'timestamp',
          'seconds': val.millisecondsSinceEpoch ~/ 1000,
          'nanoseconds': (val.millisecondsSinceEpoch % 1000) * 1000000,
        };
      }
      return val.toString();
    });
  }

  /// Decodes a JSON string and restores any Firestore Timestamps.
  static dynamic decode(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    return _restoreTimestamps(decoded);
  }

  static dynamic _restoreTimestamps(dynamic val) {
    if (val is Map) {
      if (val.containsKey('_type') && val['_type'] == 'timestamp') {
        final seconds = val['seconds'] as int;
        final nanoseconds = val['nanoseconds'] as int;
        return Timestamp(seconds, nanoseconds);
      }
      return val.map((k, v) => MapEntry(k.toString(), _restoreTimestamps(v)));
    } else if (val is List) {
      return val.map((v) => _restoreTimestamps(v)).toList();
    }
    return val;
  }
}
