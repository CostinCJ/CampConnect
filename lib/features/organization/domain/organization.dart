import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String ownerUid;
  final String inviteCode;

  /// Optional owner-chosen prefix for this org's camp codes (e.g. "MURES").
  /// When null/empty the app falls back to [defaultPrefixFor] the org name, so
  /// each organiser's codes look different (MURES-7K3Q vs BRASOV-2F9X).
  final String? codePrefix;

  const Organization({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.inviteCode,
    this.codePrefix,
  });

  /// The prefix actually used when minting codes: the owner's choice if set,
  /// otherwise one derived from the org name.
  String get effectiveCodePrefix =>
      (codePrefix != null && codePrefix!.trim().isNotEmpty)
          ? codePrefix!.trim().toUpperCase()
          : defaultPrefixFor(name);

  /// Derives a short A–Z/0–9 prefix (max 8 chars) from an org [name],
  /// transliterating Romanian/Hungarian diacritics so "Mureș" → "MURES".
  /// Falls back to "CAMP" when nothing usable remains.
  static String defaultPrefixFor(String name) {
    const fold = {
      'Ă': 'A', 'Â': 'A', 'Á': 'A', 'À': 'A',
      'Î': 'I', 'Í': 'I',
      'Ș': 'S', 'Ş': 'S',
      'Ț': 'T', 'Ţ': 'T',
      'Ő': 'O', 'Ö': 'O', 'Ó': 'O',
      'Ű': 'U', 'Ü': 'U', 'Ú': 'U',
      'É': 'E', 'È': 'E',
    };
    final buffer = StringBuffer();
    for (final ch in name.toUpperCase().split('')) {
      final mapped = fold[ch] ?? ch;
      if (RegExp(r'[A-Z0-9]').hasMatch(mapped)) buffer.write(mapped);
    }
    final cleaned = buffer.toString();
    if (cleaned.isEmpty) return 'CAMP';
    return cleaned.length <= 8 ? cleaned : cleaned.substring(0, 8);
  }

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      codePrefix: data['codePrefix'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'ownerUid': ownerUid,
        'inviteCode': inviteCode,
        if (codePrefix != null) 'codePrefix': codePrefix,
      };
}
