import 'package:cloud_firestore/cloud_firestore.dart';

/// A reusable announcement a guide can send with one tap and tweak before
/// posting. Content is stored per language (ro/hu/en) so the same template
/// works whatever language the sending guide uses — the guide picks which
/// language to edit in the templates manager.
class AnnouncementTemplate {
  final String id;
  final Map<String, String> titles; // languageCode -> title
  final Map<String, String> bodies; // languageCode -> body
  final int order;

  const AnnouncementTemplate({
    required this.id,
    required this.titles,
    required this.bodies,
    this.order = 0,
  });

  /// The supported content languages, in the order the editor shows them.
  static const List<String> languages = ['ro', 'hu', 'en'];

  String titleFor(String lang) => _pick(titles, lang);
  String bodyFor(String lang) => _pick(bodies, lang);

  /// Returns the [lang] value, falling back to the first non-empty language so
  /// a template half-filled in one language still shows something usable.
  static String _pick(Map<String, String> map, String lang) {
    final direct = map[lang];
    if (direct != null && direct.trim().isNotEmpty) return direct;
    for (final l in languages) {
      final fallback = map[l];
      if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    }
    return '';
  }

  factory AnnouncementTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AnnouncementTemplate(
      id: doc.id,
      titles: Map<String, String>.from(data['titles'] as Map? ?? {}),
      bodies: Map<String, String>.from(data['bodies'] as Map? ?? {}),
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'titles': titles,
        'bodies': bodies,
        'order': order,
      };

  AnnouncementTemplate copyWith({
    String? id,
    Map<String, String>? titles,
    Map<String, String>? bodies,
    int? order,
  }) {
    return AnnouncementTemplate(
      id: id ?? this.id,
      titles: titles ?? this.titles,
      bodies: bodies ?? this.bodies,
      order: order ?? this.order,
    );
  }
}

/// Built-in starter templates seeded into an org the first time its templates
/// are needed, so guides always have something to personalise from. Stable ids
/// keep a re-seed from duplicating them.
List<AnnouncementTemplate> defaultAnnouncementTemplates() {
  AnnouncementTemplate t(
    String id,
    int order, {
    required String enT,
    required String roT,
    required String huT,
    required String enB,
    required String roB,
    required String huB,
  }) {
    return AnnouncementTemplate(
      id: id,
      order: order,
      titles: {'en': enT, 'ro': roT, 'hu': huT},
      bodies: {'en': enB, 'ro': roB, 'hu': huB},
    );
  }

  return [
    t(
      'wakeup',
      0,
      enT: 'Wake-up',
      roT: 'Deșteptarea',
      huT: 'Ébresztő',
      enB: 'Good morning! Time to wake up, get dressed and get ready for the day.',
      roB: 'Bună dimineața! E timpul să vă treziți, să vă îmbrăcați și să vă pregătiți de o nouă zi.',
      huB: 'Jó reggelt! Ideje felkelni, felöltözni és készülődni a napra.',
    ),
    t(
      'meal',
      1,
      enT: 'Meal time',
      roT: 'Masa',
      huT: 'Étkezés',
      enB: 'Meal time! Please head to the dining area.',
      roB: 'E ora mesei! Vă rugăm să veniți la sala de mese.',
      huB: 'Étkezés ideje! Kérjük, fáradjatok az étkezőbe.',
    ),
    t(
      'gathering',
      2,
      enT: 'Gathering point',
      roT: 'Adunare',
      huT: 'Gyülekező',
      enB: 'Everyone gather at the meeting point.',
      roB: 'Toată lumea se adună la punctul de întâlnire.',
      huB: 'Mindenki gyülekezzen a találkozóponton.',
    ),
    t(
      'weather',
      3,
      enT: 'Weather warning',
      roT: 'Avertisment meteo',
      huT: 'Időjárás-figyelmeztetés',
      enB: 'The weather is changing. Please dress accordingly and stay safe.',
      roB: 'Vremea se schimbă. Vă rugăm să vă îmbrăcați corespunzător și să aveți grijă.',
      huB: 'Változik az időjárás. Kérjük, öltözzetek megfelelően és vigyázzatok magatokra.',
    ),
    t(
      'lightsout',
      4,
      enT: 'Lights out',
      roT: 'Stingerea',
      huT: 'Villanyoltás',
      enB: 'Lights out. Time to sleep — good night!',
      roB: 'Stingerea! E timpul de culcare — noapte bună!',
      huB: 'Villanyoltás! Ideje aludni — jó éjszakát!',
    ),
    t(
      'freetime',
      5,
      enT: 'Free time',
      roT: 'Timp liber',
      huT: 'Szabadidő',
      enB: 'Free time! Enjoy, but please stay within the camp area.',
      roB: 'Timp liber! Distracție plăcută, dar rămâneți în perimetrul taberei.',
      huB: 'Szabadidő! Jó szórakozást, de maradjatok a tábor területén.',
    ),
    t(
      'departure',
      6,
      enT: 'Departure',
      roT: 'Plecare',
      huT: 'Indulás',
      enB: 'Get your things ready — we are leaving soon.',
      roB: 'Pregătiți-vă lucrurile — plecăm în curând.',
      huB: 'Készítsétek össze a holmitokat — hamarosan indulunk.',
    ),
    t(
      'reminder',
      7,
      enT: 'Reminder',
      roT: 'Reamintire',
      huT: 'Emlékeztető',
      enB: 'A quick reminder for everyone:',
      roB: 'O scurtă reamintire pentru toată lumea:',
      huB: 'Egy gyors emlékeztető mindenkinek:',
    ),
  ];
}
