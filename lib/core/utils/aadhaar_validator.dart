/// Verhoeff algorithm implementation for Aadhaar number validation.
///
/// The Verhoeff checksum algorithm detects all single-digit errors and
/// all transposition errors of adjacent digits.
class VerhoeffValidator {
  // Multiplication table (Dihedral group D5)
  static const List<List<int>> _d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];

  // Permutation table
  static const List<List<int>> _p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  // Inverse table
  static const List<int> _inv = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9];

  /// Validates the given [number] using the Verhoeff checksum algorithm.
  ///
  /// Returns `true` if the checksum is valid (result is 0), `false` otherwise.
  static bool validateVerhoeff(String number) {
    int c = 0;
    final myArray = _stringToReversedIntArray(number);
    for (int i = 0; i < myArray.length; i++) {
      c = _d[c][_p[(i % 8)][myArray[i]]];
    }
    return c == 0;
  }

  static List<int> _stringToReversedIntArray(String num) {
    final list = <int>[];
    for (int i = 0; i < num.length; i++) {
      list.add(int.parse(num[i]));
    }
    return list.reversed.toList();
  }

  /// Full Aadhaar validation: format check + Verhoeff checksum.
  ///
  /// Rules:
  /// 1. Must be exactly 12 digits
  /// 2. Must not start with 0 or 1
  /// 3. Must pass the Verhoeff checksum
  static bool isValidAadhaar(String aadhaar) {
    final trimmed = aadhaar.trim().replaceAll(' ', '');

    // Must be exactly 12 digits
    if (trimmed.length != 12) return false;

    // Must contain only digits
    if (!RegExp(r'^\d{12}$').hasMatch(trimmed)) return false;

    // Must not start with 0 or 1
    if (trimmed.startsWith('0') || trimmed.startsWith('1')) return false;

    // Must pass Verhoeff checksum
    return validateVerhoeff(trimmed);
  }
}
