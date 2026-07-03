class ContentFilter {
  static const _blocklist = [
    // English
    'damn',
    // Romanian
    'idiot',
    // Hungarian
    'hülye',
  ];

  bool isAllowed(String input) {
    final lower = input.toLowerCase();
    for (final word in _blocklist) {
      if (lower.contains(word)) {
        return false;
      }
    }
    return true;
  }

  String redirectMessage(String language) {
    if (language == 'hu') {
      return 'Beszéljünk a táborról! Kérdezz valamit erről a helyről.';
    }
    if (language == 'en') {
      return 'Let\'s talk about camp! Ask me something about this place.';
    }
    return 'Hai să vorbim despre tabără! Întreabă-mă ceva despre acest loc.';
  }
}
