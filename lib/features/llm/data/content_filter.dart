class ContentFilter {
  static const _blocklist = [
    // English
    'fuck', 'shit', 'ass', 'bitch', 'damn', 'crap', 'dick', 'pussy',
    'bastard', 'slut', 'whore', 'nigger', 'faggot', 'retard',
    // Romanian
    'idiot', 'prost', 'stupid', 'dracu', 'naiba', 'futui', 'cacat',
    'cur', 'pizdă', 'pulă', 'muie', 'bulău', 'căcat',
    // Hungarian
    'hülye', 'barom', 'fasz', 'kurva', 'szar', 'segg', 'geci',
    'buzi', 'köcsög', 'rohadt',
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
    return 'Hai să vorbim despre tabără! Întreabă-mă ceva despre acest loc.';
  }
}
