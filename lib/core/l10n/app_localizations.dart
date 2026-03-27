import 'package:flutter/widgets.dart';

class AppLocalizations {
  final String locale;

  AppLocalizations._(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations._('ro');
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ro'),
    Locale('hu'),
  ];

  String get appName => _t('appName');
  String get roleSelectionTitle => _t('roleSelectionTitle');
  String get imAGuide => _t('imAGuide');
  String get imAKid => _t('imAKid');
  String get guideDescription => _t('guideDescription');
  String get kidDescription => _t('kidDescription');
  String get guideLogin => _t('guideLogin');
  String get createAccount => _t('createAccount');
  String get welcomeBack => _t('welcomeBack');
  String get signUpSubtitle => _t('signUpSubtitle');
  String get signInSubtitle => _t('signInSubtitle');
  String get displayName => _t('displayName');
  String get email => _t('email');
  String get password => _t('password');
  String get signIn => _t('signIn');
  String get hasAccount => _t('hasAccount');
  String get noAccount => _t('noAccount');
  String get kidLogin => _t('kidLogin');
  String get readyForAdventure => _t('readyForAdventure');
  String get enterCampCode => _t('enterCampCode');
  String get campCode => _t('campCode');
  String get askGuideForCode => _t('askGuideForCode');
  String get letsGo => _t('letsGo');
  String get invalidCode => _t('invalidCode');
  String get hey => _t('hey');
  String get yourTeam => _t('yourTeam');
  String get quickStats => _t('quickStats');
  String get teamPoints => _t('teamPoints');
  String get journalEntries => _t('journalEntries');
  String get welcome => _t('welcome');
  String get guideDashboard => _t('guideDashboard');
  String get sessionOverview => _t('sessionOverview');
  String get activeSession => _t('activeSession');
  String get noActiveSession => _t('noActiveSession');
  String get createSessionPrompt => _t('createSessionPrompt');
  String get createSession => _t('createSession');
  String get quickActions => _t('quickActions');
  String get addPoints => _t('addPoints');
  String get postAnnouncement => _t('postAnnouncement');
  String get emergencyAlert => _t('emergencyAlert');
  String get manageCodes => _t('manageCodes');
  String get teams => _t('teams');
  String get emergency => _t('emergency');
  String get emergencyMessage => _t('emergencyMessage');
  String get send => _t('send');
  String get ok => _t('ok');
  String get somethingWentWrong => _t('somethingWentWrong');
  String get retry => _t('retry');
  String get noUserFound => _t('noUserFound');
  String get settings => _t('settings');
  String get language => _t('language');
  String get romanian => _t('romanian');
  String get hungarian => _t('hungarian');
  String get darkMode => _t('darkMode');
  String get darkThemeActive => _t('darkThemeActive');
  String get lightThemeActive => _t('lightThemeActive');
  String get logout => _t('logout');
  String get campManagement => _t('campManagement');
  String get campSessionManagement => _t('campSessionManagement');
  String get campSessionManagementSubtitle => _t('campSessionManagementSubtitle');
  String get codeManagement => _t('codeManagement');
  String get codeManagementSubtitle => _t('codeManagementSubtitle');
  String get noActivecamp => _t('noActivecamp');
  String get selectCampFirst => _t('selectCampFirst');
  String get noCodesYet => _t('noCodesYet');
  String get tapToGenerate => _t('tapToGenerate');
  String get generateCodes => _t('generateCodes');
  String get team => _t('team');
  String get numberOfCodes => _t('numberOfCodes');
  String get generate => _t('generate');
  String get cancel => _t('cancel');
  String get used => _t('used');
  String get available => _t('available');
  String get codes => _t('codes');
  String get home => _t('home');
  String get leaderboard => _t('leaderboard');
  String get map => _t('map');
  String get journal => _t('journal');
  String get news => _t('news');
  String get announcements => _t('announcements');
  String get leaderboardComingSoon => _t('leaderboardComingSoon');
  String get mapComingSoon => _t('mapComingSoon');
  String get journalComingSoon => _t('journalComingSoon');
  String get announcementsComingSoon => _t('announcementsComingSoon');
  String get emergencyComingSoon => _t('emergencyComingSoon');
  String get emailRequired => _t('emailRequired');
  String get emailInvalid => _t('emailInvalid');
  String get passwordRequired => _t('passwordRequired');
  String get passwordTooShort => _t('passwordTooShort');
  String get campCodeRequired => _t('campCodeRequired');
  String get campCodeInvalid => _t('campCodeInvalid');
  String get fieldRequired => _t('fieldRequired');
  String get inviteCode => _t('inviteCode');
  String get invalidInviteCode => _t('invalidInviteCode');
  String get emailAlreadyInUse => _t('emailAlreadyInUse');
  String get wrongCredentials => _t('wrongCredentials');
  String get tooManyAttempts => _t('tooManyAttempts');
  String get networkError => _t('networkError');
  String get codeAlreadyUsed => _t('codeAlreadyUsed');
  String get sessionExpired => _t('sessionExpired');
  String get campSessions => _t('campSessions');
  String get newSession => _t('newSession');
  String get createCampSession => _t('createCampSession');
  String get sessionName => _t('sessionName');
  String get sessionNameHint => _t('sessionNameHint');
  String get selectStartDate => _t('selectStartDate');
  String get selectEndDate => _t('selectEndDate');
  String get noSessionsYet => _t('noSessionsYet');
  String get tapToCreate => _t('tapToCreate');
  String get active => _t('active');
  String get ended => _t('ended');
  String get inProgress => _t('inProgress');
  String get activeSessionSet => _t('activeSessionSet');
  String get enterSessionName => _t('enterSessionName');
  String get selectDates => _t('selectDates');
  String get selectAtLeastOneTeam => _t('selectAtLeastOneTeam');
  String get start => _t('start');
  String get end => _t('end');

  String generatedCodesFor(int count, String teamName) =>
      _t('generatedCodesFor')
          .replaceAll('{count}', count.toString())
          .replaceAll('{team}', teamName);

  String teamsCount(int count) {
    if (locale == 'hu') {
      return '$count csapat';
    }
    return count == 1 ? '$count echipa' : '$count echipe';
  }

  String codesCount(int count) => "$count ${_t("codes")}";

  String _t(String key) {
    final map = locale == 'hu' ? _hu : _ro;
    return map[key] ?? _ro[key] ?? key;
  }

  static const Map<String, String> _ro = {
    'appName': 'CampConnect',
    'roleSelectionTitle': 'Cine esti?',
    'imAGuide': 'Sunt Ghid',
    'imAKid': 'Sunt Copil',
    'guideDescription': 'Gestioneaza tabara si activitatile',
    'kidDescription': 'Alatura-te taberei cu un cod',
    'guideLogin': 'Autentificare Ghid',
    'createAccount': 'Creeaza Cont',
    'welcomeBack': 'Bine ai revenit',
    'signUpSubtitle': 'Inscrie-te pentru a-ti gestiona tabara',
    'signInSubtitle': 'Autentifica-te pentru a-ti gestiona tabara',
    'displayName': 'Nume afisat',
    'email': 'Email',
    'password': 'Parola',
    'signIn': 'Autentificare',
    'hasAccount': 'Ai deja un cont? Autentifica-te',
    'noAccount': 'Nu ai cont? Creeaza Cont',
    'kidLogin': 'Alatura-te Taberei',
    'readyForAdventure': 'Pregatit de Aventura?',
    'enterCampCode': 'Introdu codul de tabara primit de la ghid!',
    'campCode': 'Cod Tabara',
    'askGuideForCode': 'Cere codul ghidului tau',
    'letsGo': 'Hai sa mergem!',
    'invalidCode': 'Cod de tabara invalid. Verifica si incearca din nou.',
    'hey': 'Salut',
    'yourTeam': 'ECHIPA TA',
    'quickStats': 'Statistici Rapide',
    'teamPoints': 'Puncte Echipa',
    'journalEntries': 'Intrari Jurnal',
    'welcome': 'Bine ai venit',
    'guideDashboard': 'Panou Ghid',
    'sessionOverview': 'Prezentare Sesiune',
    'activeSession': 'Sesiune Activa',
    'noActiveSession': 'Nicio Sesiune de Tabara Activa',
    'createSessionPrompt': 'Creeaza o sesiune de tabara pentru a incepe.',
    'createSession': 'Creeaza Sesiune',
    'quickActions': 'Actiuni Rapide',
    'addPoints': 'Adauga Puncte',
    'postAnnouncement': 'Posteaza Anunt',
    'emergencyAlert': 'Alerta de Urgenta',
    'manageCodes': 'Gestioneaza Coduri',
    'teams': 'Echipe',
    'emergency': 'Urgenta',
    'emergencyMessage': 'Functionalitatea alertelor de urgenta va fi disponibila in curand. In caz de urgenta reala, contacteaza imediat directorul taberei.',
    'send': 'Trimite',
    'ok': 'OK',
    'somethingWentWrong': 'Ceva nu a mers bine. Te rugam incearca din nou.',
    'retry': 'Reincearca',
    'noUserFound': 'Niciun utilizator gasit.',
    'settings': 'Setari',
    'language': 'Limba',
    'romanian': 'Romana',
    'hungarian': 'Maghiara',
    'darkMode': 'Mod Intunecat',
    'darkThemeActive': 'Tema intunecata activa',
    'lightThemeActive': 'Tema luminoasa activa',
    'logout': 'Deconectare',
    'campManagement': 'Gestionare Tabara',
    'campSessionManagement': 'Gestionare Sesiuni Tabara',
    'campSessionManagementSubtitle': 'Creeaza si gestioneaza sesiunile de tabara',
    'codeManagement': 'Gestionare Coduri',
    'codeManagementSubtitle': 'Genereaza si gestioneaza codurile de acces',
    'noActivecamp': 'Nicio Sesiune de Tabara Activa',
    'selectCampFirst': 'Te rugam selecteaza o sesiune de tabara activa din Gestionare Sesiuni Tabara.',
    'noCodesYet': 'Niciun cod generat inca',
    'tapToGenerate': 'Apasa butonul de mai jos pentru a genera coduri de acces.',
    'generateCodes': 'Genereaza Coduri',
    'team': 'Echipa',
    'numberOfCodes': 'Numar de Coduri',
    'generate': 'Genereaza',
    'cancel': 'Anuleaza',
    'used': 'Folosit',
    'available': 'Disponibil',
    'codes': 'Coduri',
    'generatedCodesFor': '{count} coduri generate pentru {team}',
    'home': 'Acasa',
    'leaderboard': 'Clasament',
    'map': 'Harta',
    'journal': 'Jurnal',
    'news': 'Noutati',
    'announcements': 'Anunturi',
    'leaderboardComingSoon': 'Clasament - In curand',
    'mapComingSoon': 'Harta - In curand',
    'journalComingSoon': 'Jurnal - In curand',
    'announcementsComingSoon': 'Anunturi - In curand',
    'emergencyComingSoon': 'Alerte de Urgenta - In curand',
    'emailRequired': 'Email-ul este obligatoriu',
    'emailInvalid': 'Introdu o adresa de email valida',
    'passwordRequired': 'Parola este obligatorie',
    'passwordTooShort': 'Parola trebuie sa aiba cel putin 6 caractere',
    'campCodeRequired': 'Codul de tabara este obligatoriu',
    'campCodeInvalid': 'Format cod invalid (asteptat: CAMP-XXXX)',
    'fieldRequired': 'Acest camp este obligatoriu',
    'inviteCode': 'Cod de invitatie',
    'invalidInviteCode': 'Cod de invitatie invalid',
    'emailAlreadyInUse': 'Acest email este deja folosit',
    'wrongCredentials': 'Email sau parola incorecta',
    'tooManyAttempts': 'Prea multe incercari. Incearca din nou mai tarziu.',
    'networkError': 'Eroare de retea. Verifica conexiunea la internet.',
    'codeAlreadyUsed': 'Acest cod a fost deja folosit.',
    'sessionExpired': 'Sesiunea de tabara s-a incheiat.',
    'campSessions': 'Sesiuni Tabara',
    'newSession': 'Sesiune Noua',
    'createCampSession': 'Creeaza Sesiune Tabara',
    'sessionName': 'Numele Sesiunii',
    'sessionNameHint': 'ex. Tabara de Vara 2026',
    'selectStartDate': 'Selecteaza data de inceput',
    'selectEndDate': 'Selecteaza data de sfarsit',
    'noSessionsYet': 'Nicio sesiune de tabara inca',
    'tapToCreate': 'Apasa butonul de mai jos pentru a crea prima sesiune.',
    'active': 'Activa',
    'ended': 'Incheiata',
    'inProgress': 'In desfasurare',
    'activeSessionSet': 'Sesiunea activa setata: ',
    'enterSessionName': 'Introdu numele sesiunii',
    'selectDates': 'Selecteaza datele de inceput si sfarsit',
    'selectAtLeastOneTeam': 'Selecteaza cel putin o echipa',
    'start': 'Inceput',
    'end': 'Sfarsit',
  };

  static const Map<String, String> _hu = {
    'appName': 'CampConnect',
    'roleSelectionTitle': 'Ki vagy?',
    'imAGuide': 'Vezeto vagyok',
    'imAKid': 'Gyerek vagyok',
    'guideDescription': 'Tabor es tevekenysgek kezelese',
    'kidDescription': 'Csatlakozz a taborhoz egy koddal',
    'guideLogin': 'Vezeto Bejelentkezes',
    'createAccount': 'Fiok Letrehozasa',
    'welcomeBack': 'Udvozollek ujra',
    'signUpSubtitle': 'Regisztralj a taborod kezelesehez',
    'signInSubtitle': 'Jelentkezz be a taborod kezelesehez',
    'displayName': 'Megjelenesi nev',
    'email': 'Email',
    'password': 'Jelszo',
    'signIn': 'Bejelentkezes',
    'hasAccount': 'Van mar fiokod? Jelentkezz be',
    'noAccount': 'Nincs fiokod? Hozz letre egyet',
    'kidLogin': 'Csatlakozas a Taborhoz',
    'readyForAdventure': 'Kesz a Kalandra?',
    'enterCampCode': 'Ird be a taborkodot, amit a vezetotol kaptal!',
    'campCode': 'Taborkod',
    'askGuideForCode': 'Kerd el a kodot a vezetodtol',
    'letsGo': 'Hajra!',
    'invalidCode': 'Ervenytelen taborkod. Ellenorizd es probald ujra.',
    'hey': 'Szia',
    'yourTeam': 'A CSAPATOD',
    'quickStats': 'Gyors Statisztikak',
    'teamPoints': 'Csapatpontok',
    'journalEntries': 'Naplobejegyzesek',
    'welcome': 'Udvozollek',
    'guideDashboard': 'Vezeto Iranytopult',
    'sessionOverview': 'Szekcio Attekintes',
    'activeSession': 'Aktiv Szekcio',
    'noActiveSession': 'Nincs Aktiv Tabor Szekcio',
    'createSessionPrompt': 'Hozz letre egy tabor szekiot a kezdeshez.',
    'createSession': 'Szekcio Letrehozasa',
    'quickActions': 'Gyors Muveletek',
    'addPoints': 'Pontok Hozzaadasa',
    'postAnnouncement': 'Kozlemeny Kozetele',
    'emergencyAlert': 'Veszjelzes',
    'manageCodes': 'Kodok Kezelese',
    'teams': 'Csapatok',
    'emergency': 'Veszhely',
    'emergencyMessage': 'A veszhelyzeti riasztas funkcio hamarosan elerheto lesz. Valos veszhely eseten azonnal ertesitsd a tabor vezetojet.',
    'send': 'Kuldes',
    'ok': 'OK',
    'somethingWentWrong': 'Valami hiba tortent. Kerlek probald ujra.',
    'retry': 'Ujra',
    'noUserFound': 'Nem talalhato felhasznalo.',
    'settings': 'Beallitasok',
    'language': 'Nyelv',
    'romanian': 'Roman',
    'hungarian': 'Magyar',
    'darkMode': 'Sotet Mod',
    'darkThemeActive': 'Sotet tema aktiv',
    'lightThemeActive': 'Vilagos tema aktiv',
    'logout': 'Kijelentkezes',
    'campManagement': 'Tabor Kezeles',
    'campSessionManagement': 'Tabor Szekciok Kezelese',
    'campSessionManagementSubtitle': 'Tabor szekciok letrehozasa es kezelese',
    'codeManagement': 'Kodok Kezelese',
    'codeManagementSubtitle': 'Hozzaferesi kodok generalasa es kezelese',
    'noActivecamp': 'Nincs Aktiv Tabor Szekcio',
    'selectCampFirst': 'Kerlek valassz egy aktiv tabor szekiot a Tabor Szekciok Kezelese menuben.',
    'noCodesYet': 'Meg nincsenek kodok',
    'tapToGenerate': 'Nyomd meg az alanti gombot a hozzaferesi kodok generalsahoz.',
    'generateCodes': 'Kodok Generalasa',
    'team': 'Csapat',
    'numberOfCodes': 'Kodok Szama',
    'generate': 'Generalas',
    'cancel': 'Megse',
    'used': 'Hasznalt',
    'available': 'Elerheto',
    'codes': 'Kodok',
    'generatedCodesFor': '{count} kod generalva a {team} csapatnak',
    'home': 'Fooldal',
    'leaderboard': 'Ranglista',
    'map': 'Terkep',
    'journal': 'Naplo',
    'news': 'Hirek',
    'announcements': 'Kozlemenyek',
    'leaderboardComingSoon': 'Ranglista - Hamarosan',
    'mapComingSoon': 'Terkep - Hamarosan',
    'journalComingSoon': 'Naplo - Hamarosan',
    'announcementsComingSoon': 'Kozlemenyek - Hamarosan',
    'emergencyComingSoon': 'Veszhelyzeti Riasztasok - Hamarosan',
    'emailRequired': 'Az email megadasa kotelezo',
    'emailInvalid': 'Adj meg egy ervenyes email cimet',
    'passwordRequired': 'A jelszo megadasa kotelezo',
    'passwordTooShort': 'A jelszonak legalabb 6 karakterbol kell allnia',
    'campCodeRequired': 'A taborkod megadasa kotelezo',
    'campCodeInvalid': 'Ervenytelen kod formatum (elvart: CAMP-XXXX)',
    'fieldRequired': 'Ez a mezo kotelezo',
    'inviteCode': 'Meghivo kod',
    'invalidInviteCode': 'Ervenytelen meghivo kod',
    'emailAlreadyInUse': 'Ez az email cim mar hasznalva van',
    'wrongCredentials': 'Helytelen email vagy jelszo',
    'tooManyAttempts': 'Tul sok probalkozas. Probald ujra kesobb.',
    'networkError': 'Halozati hiba. Ellenorizd az internetkapcsolatot.',
    'codeAlreadyUsed': 'Ez a kod mar hasznalva lett.',
    'sessionExpired': 'A tabor munkamenet veget ert.',
    'campSessions': 'Tabor Szekciok',
    'newSession': 'Uj Szekcio',
    'createCampSession': 'Tabor Szekcio Letrehozasa',
    'sessionName': 'Szekcio Neve',
    'sessionNameHint': 'pl. Nyari Tabor 2026',
    'selectStartDate': 'Valaszd ki a kezdes datumat',
    'selectEndDate': 'Valaszd ki a befejezes datumat',
    'noSessionsYet': 'Meg nincs tabor szekcio',
    'tapToCreate': 'Nyomd meg az alanti gombot az elso szekcio letrehozasahoz.',
    'active': 'Aktiv',
    'ended': 'Befejezett',
    'inProgress': 'Folyamatban',
    'activeSessionSet': 'Aktiv szekcio beallitva: ',
    'enterSessionName': 'Add meg a szekcio nevet',
    'selectDates': 'Valaszd ki a kezdo es befejezo datumot',
    'selectAtLeastOneTeam': 'Valassz ki legalabb egy csapatot',
    'start': 'Kezdes',
    'end': 'Befejezes',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ro', 'hu'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations._(locale.languageCode);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
