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
    Locale('en'),
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
  String get forgotPassword => _t('forgotPassword');
  String get enterEmailForReset => _t('enterEmailForReset');
  String get resetEmailSent => _t('resetEmailSent');
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
  String get english => _t('english');
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
  String get pointsManagement => _t('pointsManagement');
  String get selectTeam => _t('selectTeam');
  String get pointAmount => _t('pointAmount');
  String get positiveNegativeHint => _t('positiveNegativeHint');
  String get reason => _t('reason');
  String get reasonHint => _t('reasonHint');
  String get submitPoints => _t('submitPoints');
  String get pointsAdded => _t('pointsAdded');
  String get pointsHistory => _t('pointsHistory');
  String get noPointsHistory => _t('noPointsHistory');
  String get teamRankings => _t('teamRankings');
  String get pts => _t('pts');
  String get enterPoints => _t('enterPoints');
  String get enterReason => _t('enterReason');
  String get invalidPointAmount => _t('invalidPointAmount');
  String get confirmPoints => _t('confirmPoints');
  String get pointsUpdated => _t('pointsUpdated');
  String get rank => _t('rank');
  String get yourTeamBadge => _t('yourTeamBadge');
  String get recentActivity => _t('recentActivity');
  String get justNow => _t('justNow');
  String get minutesAgo => _t('minutesAgo');
  String get hoursAgo => _t('hoursAgo');
  String get daysAgo => _t('daysAgo');
  String get noTeamsYet => _t('noTeamsYet');
  String get noCampSelected => _t('noCampSelected');
  String get mapComingSoon => _t('mapComingSoon');
  String get journalComingSoon => _t('journalComingSoon');
  String get announcementsComingSoon => _t('announcementsComingSoon');
  String get emergencyComingSoon => _t('emergencyComingSoon');

  // --- Announcements ---
  String get announcementsFeed => _t('announcementsFeed');
  String get announcementManagement => _t('announcementManagement');
  String get newAnnouncement => _t('newAnnouncement');
  String get editAnnouncement => _t('editAnnouncement');
  String get announcementTitle => _t('announcementTitle');
  String get announcementBody => _t('announcementBody');
  String get announcementType => _t('announcementType');
  String get typeAnnouncement => _t('typeAnnouncement');
  String get typeSchedule => _t('typeSchedule');
  String get pinnedAnnouncement => _t('pinnedAnnouncement');
  String get deleteAnnouncement => _t('deleteAnnouncement');
  String get deleteAnnouncementConfirm => _t('deleteAnnouncementConfirm');
  String get delete => _t('delete');
  String get announcementCreated => _t('announcementCreated');
  String get announcementUpdated => _t('announcementUpdated');
  String get announcementDeleted => _t('announcementDeleted');
  String get noAnnouncements => _t('noAnnouncements');
  String get noAnnouncementsYet => _t('noAnnouncementsYet');
  String get enterTitle => _t('enterTitle');
  String get enterBody => _t('enterBody');
  String get postedBy => _t('postedBy');
  String get schedule => _t('schedule');
  String get scheduleView => _t('scheduleView');
  String get allAnnouncements => _t('allAnnouncements');
  String get pinned => _t('pinned');
  String get activityName => _t('activityName');
  String get activityDescription => _t('activityDescription');
  String get selectDate => _t('selectDate');
  String get startTimeLabel => _t('startTimeLabel');
  String get endTimeLabel => _t('endTimeLabel');
  String get newScheduleEntry => _t('newScheduleEntry');
  String get editScheduleEntry => _t('editScheduleEntry');
  String get scheduleEntryCreated => _t('scheduleEntryCreated');
  String get scheduleEntryUpdated => _t('scheduleEntryUpdated');
  String get scheduleEntryDeleted => _t('scheduleEntryDeleted');
  String get noScheduleEntries => _t('noScheduleEntries');
  String get selectDateRequired => _t('selectDateRequired');
  String get selectTimeRequired => _t('selectTimeRequired');
  String get program => _t('program');
  String get whatsYourName => _t('whatsYourName');
  String get enterYourName => _t('enterYourName');
  String get nameHint => _t('nameHint');
  String get continueButton => _t('continueButton');
  String get nameRequired => _t('nameRequired');
  String get selected => _t('selected');
  String get deleteSession => _t('deleteSession');
  String get deleteSessionConfirm => _t('deleteSessionConfirm');
  String get sessionDeleted => _t('sessionDeleted');

  // --- Emergency ---
  String get emergencyAlertTitle => _t('emergencyAlertTitle');
  String get sendEmergencyAlert => _t('sendEmergencyAlert');
  String get emergencyMessageHint => _t('emergencyMessageHint');
  String get emergencyAlertSent => _t('emergencyAlertSent');
  String get emergencyHistory => _t('emergencyHistory');
  String get noEmergencyAlerts => _t('noEmergencyAlerts');
  String get acknowledge => _t('acknowledge');
  String get acknowledged => _t('acknowledged');
  String get acknowledgedBy => _t('acknowledgedBy');
  String get emergencyOverlayTitle => _t('emergencyOverlayTitle');
  String get sentBy => _t('sentBy');
  String get enterEmergencyMessage => _t('enterEmergencyMessage');
  String get emergencyConfirm => _t('emergencyConfirm');
  String get emergencyConfirmMessage => _t('emergencyConfirmMessage');

  // --- Map & Locations ---
  String get addLocation => _t('addLocation');
  String get editLocation => _t('editLocation');
  String get deleteLocation => _t('deleteLocation');
  String get deleteLocationConfirm => _t('deleteLocationConfirm');
  String get locationName => _t('locationName');
  String get locationDescription => _t('locationDescription');
  String get locationCategory => _t('locationCategory');
  String get locationPhoto => _t('locationPhoto');
  String get locationFacts => _t('locationFacts');
  String get locationFunFact => _t('locationFunFact');
  String get quizQuestion => _t('quizQuestion');
  String get quizAnswer => _t('quizAnswer');
  String get categoryAll => _t('categoryAll');
  String get categoryNature => _t('categoryNature');
  String get categoryHistorical => _t('categoryHistorical');
  String get categoryActivity => _t('categoryActivity');
  String get categoryViewpoint => _t('categoryViewpoint');
  String get addFact => _t('addFact');
  String get removeFact => _t('removeFact');
  String get takePhoto => _t('takePhoto');
  String get chooseFromGallery => _t('chooseFromGallery');
  String get saveLocation => _t('saveLocation');
  String get locationCreated => _t('locationCreated');
  String get locationUpdated => _t('locationUpdated');
  String get locationDeleted => _t('locationDeleted');
  String get noLocationsYet => _t('noLocationsYet');
  String get uploadingPhoto => _t('uploadingPhoto');
  String get savingLocation => _t('savingLocation');
  String get gpsUnavailable => _t('gpsUnavailable');
  String get locationPermissionDenied => _t('locationPermissionDenied');
  String get facts => _t('facts');
  String get funFact => _t('funFact');
  String get quiz => _t('quiz');
  String get revealAnswer => _t('revealAnswer');
  String get myLocation => _t('myLocation');
  String get enterLocationName => _t('enterLocationName');
  String get enterDescription => _t('enterDescription');
  String get enterFunFact => _t('enterFunFact');
  String get photoRequired => _t('photoRequired');

  // --- Master Locations & Knowledge Base ---
  String get mapLocations => _t('mapLocations');
  String get mapLocationsSubtitle => _t('mapLocationsSubtitle');
  String get knowledgeBase => _t('knowledgeBase');
  String get knowledgeBaseDescription => _t('knowledgeBaseDescription');
  String get knowledgeBaseFacts => _t('knowledgeBaseFacts');
  String get knowledgeBaseFunFact => _t('knowledgeBaseFunFact');
  String get knowledgeBaseDescriptionHint => _t('knowledgeBaseDescriptionHint');
  String get knowledgeBaseFactsHint => _t('knowledgeBaseFactsHint');
  String get knowledgeBaseFunFactHint => _t('knowledgeBaseFunFactHint');
  String get knowledgeBaseSaved => _t('knowledgeBaseSaved');
  String get noMasterLocations => _t('noMasterLocations');
  String get addToSession => _t('addToSession');
  String get selectLocation => _t('selectLocation');
  String get groupPhoto => _t('groupPhoto');
  String get groupPhotoHint => _t('groupPhotoHint');
  String get locationAddedToSession => _t('locationAddedToSession');
  String get locationAlreadyInSession => _t('locationAlreadyInSession');
  String get removeFromSession => _t('removeFromSession');
  String get removeFromSessionConfirm => _t('removeFromSessionConfirm');
  String get locationRemovedFromSession => _t('locationRemovedFromSession');

  // --- Journal ---
  String get newEntry => _t('newEntry');
  String get editEntry => _t('editEntry');
  String get journalTitle => _t('journalTitle');
  String get journalBody => _t('journalBody');
  String get journalDate => _t('journalDate');
  String get journalPhotos => _t('journalPhotos');
  String get addPhoto => _t('addPhoto');
  String get removePhoto => _t('removePhoto');
  String get saveEntry => _t('saveEntry');
  String get deleteEntry => _t('deleteEntry');
  String get deleteEntryConfirm => _t('deleteEntryConfirm');
  String get entryCreated => _t('entryCreated');
  String get entryUpdated => _t('entryUpdated');
  String get entryDeleted => _t('entryDeleted');
  String get noJournalEntries => _t('noJournalEntries');
  String get startWriting => _t('startWriting');
  String get enterJournalTitle => _t('enterJournalTitle');
  String get enterJournalBody => _t('enterJournalBody');
  String get exportPdf => _t('exportPdf');
  String get exportingPdf => _t('exportingPdf');
  String get pdfExported => _t('pdfExported');
  String get pdfExportError => _t('pdfExportError');
  String get myCampJournal => _t('myCampJournal');
  String get todayEntry => _t('todayEntry');

  String get emailRequired => _t('emailRequired');
  String get emailInvalid => _t('emailInvalid');
  String get passwordRequired => _t('passwordRequired');
  String get passwordTooShort => _t('passwordTooShort');
  String get campCodeRequired => _t('campCodeRequired');
  String get campCodeInvalid => _t('campCodeInvalid');
  String get fieldRequired => _t('fieldRequired');
  String get inviteCode => _t('inviteCode');
  String get invalidInviteCode => _t('invalidInviteCode');
  String get joinOrganization => _t('joinOrganization');
  String get createOrganization => _t('createOrganization');
  String get organizationName => _t('organizationName');
  String get organizationCode => _t('organizationCode');
  String get organizationInviteCode => _t('organizationInviteCode');
  String get inviteCodeCopied => _t('inviteCodeCopied');
  String get emailAlreadyInUse => _t('emailAlreadyInUse');
  String get wrongCredentials => _t('wrongCredentials');
  String get tooManyAttempts => _t('tooManyAttempts');
  String get networkError => _t('networkError');
  String get codeAlreadyUsed => _t('codeAlreadyUsed');
  String get sessionExpired => _t('sessionExpired');
  String get teamRank => _t('teamRank');
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
  String get endDateBeforeStart => _t('endDateBeforeStart');
  String get teamName => _t('teamName');
  String get addTeam => _t('addTeam');
  String get editTeam => _t('editTeam');
  String get deleteTeamTitle => _t('deleteTeamTitle');
  String deleteTeamConfirm(String name) => locale == 'hu'
      ? 'Biztosan törlöd a(z) $name csapatot?'
      : locale == 'en'
          ? 'Delete team $name?'
          : 'Sigur ștergi echipa $name?';
  String get cannotDeleteLastTeam => _t('cannotDeleteLastTeam');
  String get teamsManagementSubtitle => _t('teamsManagementSubtitle');
  String reassignKidsPrompt(int count) => locale == 'hu'
      ? '$count gyerek átsorolása ide:'
      : locale == 'en'
          ? 'Reassign $count kids to:'
          : 'Mută $count copii în echipa:';
  String get start => _t('start');
  String get end => _t('end');

  String get startChat => _t('startChat');
  String get loadingGuide => _t('loadingGuide');
  String get chatPlaceholder => _t('chatPlaceholder');
  String get newConversation => _t('newConversation');

  String generatedCodesFor(int count, String teamName) =>
      _t('generatedCodesFor')
          .replaceAll('{count}', count.toString())
          .replaceAll('{team}', teamName);

  String confirmPointsMessage(int amount, String teamName) {
    final absAmount = amount.abs();
    if (locale == 'en') {
      final verb = amount >= 0 ? 'Add' : 'Remove';
      final preposition = amount >= 0 ? 'to' : 'from';
      return '$verb $absAmount points $preposition $teamName?';
    }
    final action = amount >= 0
        ? (locale == 'hu' ? 'hozzaad' : 'adauga')
        : (locale == 'hu' ? 'levon' : 'scade');
    return locale == 'hu'
        ? '$absAmount pont $action a $teamName csapatnak?'
        : '$action $absAmount puncte pentru $teamName?';
  }

  String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return justNow;
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} $minutesAgo';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} $hoursAgo';
    }
    return '${diff.inDays} $daysAgo';
  }

  String teamsCount(int count) {
    if (locale == 'hu') {
      return '$count csapat';
    }
    if (locale == 'en') {
      return count == 1 ? '$count team' : '$count teams';
    }
    return count == 1 ? '$count echipa' : '$count echipe';
  }

  String codesCount(int count) => "$count ${_t("codes")}";

  String _t(String key) {
    final Map<String, String> map;
    if (locale == 'hu') {
      map = _hu;
    } else if (locale == 'en') {
      map = _en;
    } else {
      map = _ro;
    }
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
    'forgotPassword': 'Ai uitat parola?',
    'enterEmailForReset': 'Introdu adresa de email pentru resetare.',
    'resetEmailSent': 'Ți-am trimis un email de resetare.',
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
    'english': 'Engleza',
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
    'pointsManagement': 'Gestionare Puncte',
    'selectTeam': 'Selecteaza Echipa',
    'pointAmount': 'Numar de Puncte',
    'positiveNegativeHint': 'Pozitiv = adauga puncte, Negativ = scade puncte',
    'reason': 'Motiv',
    'reasonHint': 'ex. A castigat cursa de stafeta',
    'submitPoints': 'Trimite Puncte',
    'pointsAdded': 'Puncte adaugate cu succes!',
    'pointsHistory': 'Istoric Puncte',
    'noPointsHistory': 'Nicio modificare de puncte inca',
    'teamRankings': 'Clasament Echipe',
    'pts': 'pct',
    'enterPoints': 'Introdu numarul de puncte',
    'enterReason': 'Introdu un motiv',
    'invalidPointAmount': 'Introdu un numar valid (diferit de 0)',
    'confirmPoints': 'Confirma Puncte',
    'pointsUpdated': 'Punctele au fost actualizate!',
    'rank': 'Loc',
    'yourTeamBadge': 'Echipa Ta',
    'recentActivity': 'Activitate Recenta',
    'justNow': 'Chiar acum',
    'minutesAgo': 'min in urma',
    'hoursAgo': 'ore in urma',
    'daysAgo': 'zile in urma',
    'noTeamsYet': 'Nicio echipa inca',
    'noCampSelected': 'Selecteaza o sesiune de tabara',
    'mapComingSoon': 'Harta - In curand',
    'journalComingSoon': 'Jurnal - In curand',
    'announcementsComingSoon': 'Anunturi - In curand',
    'emergencyComingSoon': 'Alerte de Urgenta - In curand',
    // Journal
    'newEntry': 'Intrare Noua',
    'editEntry': 'Editeaza Intrare',
    'journalTitle': 'Titlu',
    'journalBody': 'Ce s-a intamplat azi?',
    'journalDate': 'Data',
    'journalPhotos': 'Fotografii',
    'addPhoto': 'Adauga Fotografie',
    'removePhoto': 'Sterge Fotografia',
    'saveEntry': 'Salveaza',
    'deleteEntry': 'Sterge Intrarea',
    'deleteEntryConfirm': 'Esti sigur ca vrei sa stergi aceasta intrare din jurnal?',
    'entryCreated': 'Intrare creata cu succes!',
    'entryUpdated': 'Intrare actualizata cu succes!',
    'entryDeleted': 'Intrare stearsa!',
    'noJournalEntries': 'Nicio intrare in jurnal inca',
    'startWriting': 'Apasa butonul de mai jos pentru a incepe sa scrii!',
    'enterJournalTitle': 'Introdu un titlu',
    'enterJournalBody': 'Scrie ce s-a intamplat...',
    'exportPdf': 'Exporta PDF',
    'exportingPdf': 'Se genereaza PDF-ul...',
    'pdfExported': 'Jurnal exportat cu succes!',
    'pdfExportError': 'Eroare la export. Te rugam incearca din nou.',
    'myCampJournal': 'Jurnalul Meu de Tabara',
    'todayEntry': 'Intrare de azi',
    'emailRequired': 'Email-ul este obligatoriu',
    'emailInvalid': 'Introdu o adresa de email valida',
    'passwordRequired': 'Parola este obligatorie',
    'passwordTooShort': 'Parola trebuie sa aiba cel putin 6 caractere',
    'campCodeRequired': 'Codul de tabara este obligatoriu',
    'campCodeInvalid': 'Format cod invalid (asteptat: CAMP-XXXX)',
    'fieldRequired': 'Acest camp este obligatoriu',
    'inviteCode': 'Cod de invitatie',
    'invalidInviteCode': 'Cod de invitatie invalid',
    'joinOrganization': 'Alătură-te unei organizații',
    'createOrganization': 'Creează o organizație',
    'organizationName': 'Numele organizației',
    'organizationCode': 'Codul organizației',
    'organizationInviteCode': 'Codul de invitație al organizației',
    'inviteCodeCopied': 'Cod copiat în clipboard!',
    'emailAlreadyInUse': 'Acest email este deja folosit',
    'wrongCredentials': 'Email sau parola incorecta',
    'tooManyAttempts': 'Prea multe incercari. Incearca din nou mai tarziu.',
    'networkError': 'Eroare de retea. Verifica conexiunea la internet.',
    'codeAlreadyUsed': 'Acest cod a fost deja folosit.',
    'sessionExpired': 'Sesiunea de tabara s-a incheiat.',
    'teamRank': 'Locul echipei',
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
    'endDateBeforeStart': 'Data de sfârșit nu poate fi înaintea celei de început.',
    'teamName': 'Numele echipei',
    'addTeam': 'Adaugă echipă',
    'editTeam': 'Editează echipa',
    'deleteTeamTitle': 'Șterge echipa',
    'cannotDeleteLastTeam': 'Nu poți șterge ultima echipă.',
    'teamsManagementSubtitle': 'Adaugă, redenumește sau șterge echipe',
    'start': 'Inceput',
    'end': 'Sfarsit',
    // Announcements
    'announcementsFeed': 'Noutati',
    'announcementManagement': 'Gestionare Anunturi',
    'newAnnouncement': 'Anunt Nou',
    'editAnnouncement': 'Editeaza Anunt',
    'announcementTitle': 'Titlu',
    'announcementBody': 'Continut',
    'announcementType': 'Tip',
    'typeAnnouncement': 'Anunt',
    'typeSchedule': 'Program',
    'pinnedAnnouncement': 'Fixat in top',
    'deleteAnnouncement': 'Sterge Anunt',
    'deleteAnnouncementConfirm': 'Esti sigur ca vrei sa stergi acest anunt?',
    'delete': 'Sterge',
    'announcementCreated': 'Anunt creat cu succes!',
    'announcementUpdated': 'Anunt actualizat cu succes!',
    'announcementDeleted': 'Anunt sters!',
    'noAnnouncements': 'Niciun anunt',
    'noAnnouncementsYet': 'Niciun anunt inca. Revino mai tarziu!',
    'enterTitle': 'Introdu titlul',
    'enterBody': 'Introdu continutul',
    'postedBy': 'Postat de',
    'schedule': 'Program',
    'scheduleView': 'Vizualizare Program',
    'allAnnouncements': 'Toate Anunturile',
    'pinned': 'Fixat',
    // Emergency
    'emergencyAlertTitle': 'ALERTA DE URGENTA',
    'sendEmergencyAlert': 'Trimite Alerta de Urgenta',
    'emergencyMessageHint': 'ex. Copil ranit la lac, am nevoie de ajutor',
    'emergencyAlertSent': 'Alerta de urgenta trimisa!',
    'emergencyHistory': 'Istoric Alerte',
    'noEmergencyAlerts': 'Nicio alerta de urgenta',
    'acknowledge': 'Am confirmat',
    'acknowledged': 'Confirmat',
    'acknowledgedBy': 'Confirmat de',
    'emergencyOverlayTitle': 'URGENTA',
    'sentBy': 'Trimis de',
    'enterEmergencyMessage': 'Introdu mesajul de urgenta',
    'emergencyConfirm': 'Confirma trimiterea',
    'emergencyConfirmMessage': 'Aceasta va trimite o alerta de urgenta tuturor ghizilor. Continui?',
    // Map & Locations
    'addLocation': 'Adauga Locatie',
    'editLocation': 'Editeaza Locatie',
    'deleteLocation': 'Sterge Locatie',
    'deleteLocationConfirm': 'Esti sigur ca vrei sa stergi aceasta locatie?',
    'locationName': 'Nume Locatie',
    'locationDescription': 'Descriere',
    'locationCategory': 'Categorie',
    'locationPhoto': 'Fotografie',
    'locationFacts': 'Informatii',
    'locationFunFact': 'Fapt Amuzant',
    'quizQuestion': 'Intrebare Quiz',
    'quizAnswer': 'Raspuns Quiz',
    'categoryAll': 'Toate',
    'categoryNature': 'Natura',
    'categoryHistorical': 'Istoric',
    'categoryActivity': 'Activitate',
    'categoryViewpoint': 'Punct Panoramic',
    'addFact': 'Adauga',
    'removeFact': 'Sterge',
    'takePhoto': 'Fa o Fotografie',
    'chooseFromGallery': 'Alege din Galerie',
    'saveLocation': 'Salveaza Locatia',
    'locationCreated': 'Locatie creata cu succes!',
    'locationUpdated': 'Locatie actualizata cu succes!',
    'locationDeleted': 'Locatie stearsa!',
    'noLocationsYet': 'Nicio locatie adaugata inca',
    'uploadingPhoto': 'Se incarca fotografia...',
    'savingLocation': 'Se salveaza locatia...',
    'gpsUnavailable': 'GPS indisponibil',
    'locationPermissionDenied': 'Permisiunea de localizare a fost refuzata',
    'facts': 'Informatii',
    'funFact': 'Fapt Amuzant',
    'quiz': 'Quiz',
    'revealAnswer': 'Arata Raspunsul',
    'myLocation': 'Locatia Mea',
    'enterLocationName': 'Introdu numele locatiei',
    'enterDescription': 'Introdu o descriere',
    'enterFunFact': 'Introdu un fapt amuzant',
    'photoRequired': 'Te rugam adauga o fotografie',
    // Master Locations & Knowledge Base
    'mapLocations': 'Locatii pe Harta',
    'mapLocationsSubtitle': 'Gestioneaza locatiile si baza de cunostinte',
    'knowledgeBase': 'Baza de Cunostinte',
    'knowledgeBaseDescription': 'Descriere',
    'knowledgeBaseFacts': 'Informatii',
    'knowledgeBaseFunFact': 'Fapt Amuzant',
    'knowledgeBaseDescriptionHint': 'Scrie o descriere generala a locului...',
    'knowledgeBaseFactsHint': 'Scrie informatii interesante despre acest loc...',
    'knowledgeBaseFunFactHint': 'Scrie un fapt amuzant sau surprinzator...',
    'knowledgeBaseSaved': 'Baza de cunostinte salvata!',
    'noMasterLocations': 'Nicio locatie creata inca',
    'addToSession': 'Adauga la Sesiune',
    'selectLocation': 'Selecteaza Locatia',
    'groupPhoto': 'Fotografie de Grup',
    'groupPhotoHint': 'Adauga o fotografie cu grupul la aceasta locatie',
    'locationAddedToSession': 'Locatie adaugata la sesiune!',
    'locationAlreadyInSession': 'Aceasta locatie este deja adaugata la sesiune',
    'removeFromSession': 'Sterge din Sesiune',
    'removeFromSessionConfirm': 'Esti sigur ca vrei sa stergi aceasta locatie din sesiune?',
    'locationRemovedFromSession': 'Locatie stearsa din sesiune!',
    // Schedule
    'activityName': 'Numele Activitatii',
    'activityDescription': 'Descriere (optional)',
    'selectDate': 'Selecteaza Data',
    'startTimeLabel': 'Ora de inceput',
    'endTimeLabel': 'Ora de sfarsit',
    'newScheduleEntry': 'Activitate Noua',
    'editScheduleEntry': 'Editeaza Activitate',
    'scheduleEntryCreated': 'Activitate adaugata!',
    'scheduleEntryUpdated': 'Activitate actualizata!',
    'scheduleEntryDeleted': 'Activitate stearsa!',
    'noScheduleEntries': 'Nicio activitate programata inca',
    'selectDateRequired': 'Selecteaza o data',
    'selectTimeRequired': 'Selecteaza ora',
    'program': 'Program',
    'whatsYourName': 'Cum te cheama?',
    'enterYourName': 'Introdu numele tau',
    'nameHint': 'ex. Andrei',
    'continueButton': 'Continua',
    'nameRequired': 'Te rugam introdu numele tau',
    'selected': 'Selectata',
    'deleteSession': 'Sterge Sesiunea',
    'deleteSessionConfirm': 'Esti sigur ca vrei sa stergi aceasta sesiune? Toate datele vor fi pierdute.',
    'sessionDeleted': 'Sesiune stearsa!',
    'startChat': 'Începe conversația',
    'loadingGuide': 'Se încarcă ghidul...',
    'chatPlaceholder': 'Întreabă ceva despre acest loc...',
    'newConversation': 'Conversație nouă',
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
    'forgotPassword': 'Elfelejtetted a jelszót?',
    'enterEmailForReset': 'Add meg az email-címed a visszaállításhoz.',
    'resetEmailSent': 'Elküldtük a jelszó-visszaállító emailt.',
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
    'english': 'Angol',
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
    'pointsManagement': 'Pontok Kezelese',
    'selectTeam': 'Csapat Valasztasa',
    'pointAmount': 'Pontok Szama',
    'positiveNegativeHint': 'Pozitiv = pontok hozzaadasa, Negativ = pontok levonasa',
    'reason': 'Ok',
    'reasonHint': 'pl. Megnyerte a stafetat',
    'submitPoints': 'Pontok Kuldese',
    'pointsAdded': 'Pontok sikeresen hozzaadva!',
    'pointsHistory': 'Pont Elozmeny',
    'noPointsHistory': 'Meg nincs pontvaltozas',
    'teamRankings': 'Csapat Ranglista',
    'pts': 'pt',
    'enterPoints': 'Add meg a pontok szamat',
    'enterReason': 'Add meg az okot',
    'invalidPointAmount': 'Adj meg egy ervenyes szamot (nem 0)',
    'confirmPoints': 'Pontok Megerositese',
    'pointsUpdated': 'A pontok frissultek!',
    'rank': 'Hely',
    'yourTeamBadge': 'A Csapatod',
    'recentActivity': 'Legutobb Tortent',
    'justNow': 'Most',
    'minutesAgo': 'perce',
    'hoursAgo': 'oraja',
    'daysAgo': 'napja',
    'noTeamsYet': 'Meg nincsenek csapatok',
    'noCampSelected': 'Valassz egy tabor szekiot',
    'mapComingSoon': 'Terkep - Hamarosan',
    'journalComingSoon': 'Naplo - Hamarosan',
    'announcementsComingSoon': 'Kozlemenyek - Hamarosan',
    'emergencyComingSoon': 'Veszhelyzeti Riasztasok - Hamarosan',
    // Journal
    'newEntry': 'Uj Bejegyzes',
    'editEntry': 'Bejegyzes Szerkesztese',
    'journalTitle': 'Cim',
    'journalBody': 'Mi tortent ma?',
    'journalDate': 'Datum',
    'journalPhotos': 'Fenykepek',
    'addPhoto': 'Fenykep Hozzaadasa',
    'removePhoto': 'Fenykep Torlese',
    'saveEntry': 'Mentes',
    'deleteEntry': 'Bejegyzes Torlese',
    'deleteEntryConfirm': 'Biztosan torolni szeretned ezt a naplobejegyzest?',
    'entryCreated': 'Bejegyzes sikeresen letrehozva!',
    'entryUpdated': 'Bejegyzes sikeresen frissitve!',
    'entryDeleted': 'Bejegyzes torolve!',
    'noJournalEntries': 'Meg nincsenek naplobejegyzesek',
    'startWriting': 'Nyomd meg az alanti gombot az irashoz!',
    'enterJournalTitle': 'Adj meg egy cimet',
    'enterJournalBody': 'Ird le mi tortent...',
    'exportPdf': 'PDF Exportalas',
    'exportingPdf': 'PDF generalasa...',
    'pdfExported': 'Naplo sikeresen exportalva!',
    'pdfExportError': 'Hiba az exportalasnal. Probald ujra.',
    'myCampJournal': 'Tabori Naplom',
    'todayEntry': 'Mai bejegyzes',
    'emailRequired': 'Az email megadasa kotelezo',
    'emailInvalid': 'Adj meg egy ervenyes email cimet',
    'passwordRequired': 'A jelszo megadasa kotelezo',
    'passwordTooShort': 'A jelszonak legalabb 6 karakterbol kell allnia',
    'campCodeRequired': 'A taborkod megadasa kotelezo',
    'campCodeInvalid': 'Ervenytelen kod formatum (elvart: CAMP-XXXX)',
    'fieldRequired': 'Ez a mezo kotelezo',
    'inviteCode': 'Meghivo kod',
    'invalidInviteCode': 'Ervenytelen meghivo kod',
    'joinOrganization': 'Csatlakozás szervezethez',
    'createOrganization': 'Szervezet létrehozása',
    'organizationName': 'Szervezet neve',
    'organizationCode': 'Szervezet kódja',
    'organizationInviteCode': 'A szervezet meghívó kódja',
    'inviteCodeCopied': 'Kód a vágólapra másolva!',
    'emailAlreadyInUse': 'Ez az email cim mar hasznalva van',
    'wrongCredentials': 'Helytelen email vagy jelszo',
    'tooManyAttempts': 'Tul sok probalkozas. Probald ujra kesobb.',
    'networkError': 'Halozati hiba. Ellenorizd az internetkapcsolatot.',
    'codeAlreadyUsed': 'Ez a kod mar hasznalva lett.',
    'sessionExpired': 'A tabor munkamenet veget ert.',
    'teamRank': 'Csapat helyezes',
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
    'endDateBeforeStart': 'A befejezés dátuma nem lehet korábbi a kezdésnél.',
    'teamName': 'Csapat neve',
    'addTeam': 'Csapat hozzáadása',
    'editTeam': 'Csapat szerkesztése',
    'deleteTeamTitle': 'Csapat törlése',
    'cannotDeleteLastTeam': 'Az utolsó csapat nem törölhető.',
    'teamsManagementSubtitle': 'Csapatok hozzáadása, átnevezése, törlése',
    'start': 'Kezdes',
    'end': 'Befejezes',
    // Announcements
    'announcementsFeed': 'Hirek',
    'announcementManagement': 'Kozlemenyek Kezelese',
    'newAnnouncement': 'Uj Kozlemeny',
    'editAnnouncement': 'Kozlemeny Szerkesztese',
    'announcementTitle': 'Cim',
    'announcementBody': 'Tartalom',
    'announcementType': 'Tipus',
    'typeAnnouncement': 'Kozlemeny',
    'typeSchedule': 'Program',
    'pinnedAnnouncement': 'Kituzve',
    'deleteAnnouncement': 'Kozlemeny Torlese',
    'deleteAnnouncementConfirm': 'Biztosan torolni szeretned ezt a kozlemenyt?',
    'delete': 'Torles',
    'announcementCreated': 'Kozlemeny sikeresen letrehozva!',
    'announcementUpdated': 'Kozlemeny sikeresen frissitve!',
    'announcementDeleted': 'Kozlemeny torolve!',
    'noAnnouncements': 'Nincs kozlemeny',
    'noAnnouncementsYet': 'Meg nincs kozlemeny. Nezz vissza kesobb!',
    'enterTitle': 'Add meg a cimet',
    'enterBody': 'Add meg a tartalmat',
    'postedBy': 'Koztette',
    'schedule': 'Program',
    'scheduleView': 'Program Nezet',
    'allAnnouncements': 'Osszes Kozlemeny',
    'pinned': 'Kituzve',
    // Emergency
    'emergencyAlertTitle': 'VESZHELYZETI RIASZTAS',
    'sendEmergencyAlert': 'Veszjelzes Kuldese',
    'emergencyMessageHint': 'pl. Gyerek megserult a tonal, segitseg kell',
    'emergencyAlertSent': 'Veszjelzes elkuldve!',
    'emergencyHistory': 'Riasztas Elozmeny',
    'noEmergencyAlerts': 'Nincs veszhelyzeti riasztas',
    'acknowledge': 'Megerositom',
    'acknowledged': 'Megerositve',
    'acknowledgedBy': 'Megerositette',
    'emergencyOverlayTitle': 'VESZHELY',
    'sentBy': 'Kuldte',
    'enterEmergencyMessage': 'Ird be a veszhelyzeti uzenetet',
    'emergencyConfirm': 'Kuldes megerositese',
    'emergencyConfirmMessage': 'Ez veszhelyzeti riasztast kuld minden vezetonek. Folytatod?',
    // Map & Locations
    'addLocation': 'Helyszin Hozzaadasa',
    'editLocation': 'Helyszin Szerkesztese',
    'deleteLocation': 'Helyszin Torlese',
    'deleteLocationConfirm': 'Biztosan torolni szeretned ezt a helyszint?',
    'locationName': 'Helyszin Neve',
    'locationDescription': 'Leiras',
    'locationCategory': 'Kategoria',
    'locationPhoto': 'Fenykep',
    'locationFacts': 'Informaciok',
    'locationFunFact': 'Erdekes Teny',
    'quizQuestion': 'Kviz Kerdes',
    'quizAnswer': 'Kviz Valasz',
    'categoryAll': 'Osszes',
    'categoryNature': 'Termeszet',
    'categoryHistorical': 'Tortenelmi',
    'categoryActivity': 'Aktivitas',
    'categoryViewpoint': 'Kilatopontok',
    'addFact': 'Hozzaadas',
    'removeFact': 'Torles',
    'takePhoto': 'Fenykep Keszitese',
    'chooseFromGallery': 'Valasztas a Galeriabol',
    'saveLocation': 'Helyszin Mentese',
    'locationCreated': 'Helyszin sikeresen letrehozva!',
    'locationUpdated': 'Helyszin sikeresen frissitve!',
    'locationDeleted': 'Helyszin torolve!',
    'noLocationsYet': 'Meg nincs helyszin hozzaadva',
    'uploadingPhoto': 'Fenykep feltoltese...',
    'savingLocation': 'Helyszin mentese...',
    'gpsUnavailable': 'GPS nem elerheto',
    'locationPermissionDenied': 'Helymeghatározási engedélyt megtagadva',
    'facts': 'Informaciok',
    'funFact': 'Erdekes Teny',
    'quiz': 'Kviz',
    'revealAnswer': 'Valasz Mutatasa',
    'myLocation': 'Sajat Helyzet',
    'enterLocationName': 'Add meg a helyszin nevet',
    'enterDescription': 'Add meg a leirast',
    'enterFunFact': 'Adj meg egy erdekes tenyt',
    'photoRequired': 'Kerem adj hozza egy fenyképet',
    // Master Locations & Knowledge Base
    'mapLocations': 'Terkep Helyszinek',
    'mapLocationsSubtitle': 'Helyszinek es tudastarkezeles',
    'knowledgeBase': 'Tudastar',
    'knowledgeBaseDescription': 'Leiras',
    'knowledgeBaseFacts': 'Informaciok',
    'knowledgeBaseFunFact': 'Erdekes Teny',
    'knowledgeBaseDescriptionHint': 'Irj egy altalanos leirast a helyrol...',
    'knowledgeBaseFactsHint': 'Irj erdekes informaciokat errol a helyrol...',
    'knowledgeBaseFunFactHint': 'Irj egy erdekes vagy meglepo tenyt...',
    'knowledgeBaseSaved': 'Tudastar mentve!',
    'noMasterLocations': 'Meg nincs helyszin letrehozva',
    'addToSession': 'Hozzaadas a Szekciohoz',
    'selectLocation': 'Helyszin Kivalasztasa',
    'groupPhoto': 'Csoportkep',
    'groupPhotoHint': 'Adj hozza egy csoportkepet ezen a helyszinen',
    'locationAddedToSession': 'Helyszin hozzaadva a szekciohoz!',
    'locationAlreadyInSession': 'Ez a helyszin mar hozzaadva a szekciohoz',
    'removeFromSession': 'Eltavolitas a Szekciobol',
    'removeFromSessionConfirm': 'Biztosan eltavolitod ezt a helyszint a szekciobol?',
    'locationRemovedFromSession': 'Helyszin eltavolitva a szekciobol!',
    // Schedule
    'activityName': 'Tevekenyseg Neve',
    'activityDescription': 'Leiras (opcionalis)',
    'selectDate': 'Datum Valasztasa',
    'startTimeLabel': 'Kezdes ideje',
    'endTimeLabel': 'Befejezes ideje',
    'newScheduleEntry': 'Uj Tevekenyseg',
    'editScheduleEntry': 'Tevekenyseg Szerkesztese',
    'scheduleEntryCreated': 'Tevekenyseg hozzaadva!',
    'scheduleEntryUpdated': 'Tevekenyseg frissitve!',
    'scheduleEntryDeleted': 'Tevekenyseg torolve!',
    'noScheduleEntries': 'Meg nincs betemezett tevekenyseg',
    'selectDateRequired': 'Valassz datumot',
    'selectTimeRequired': 'Valaszd ki az idot',
    'program': 'Program',
    'whatsYourName': 'Hogy hivnak?',
    'enterYourName': 'Ird be a neved',
    'nameHint': 'pl. Balazs',
    'continueButton': 'Tovabb',
    'nameRequired': 'Kerlek ird be a neved',
    'selected': 'Kijelolt',
    'deleteSession': 'Szekcio Torlese',
    'deleteSessionConfirm': 'Biztosan torolni szeretned ezt a szekiot? Minden adat elveszik.',
    'sessionDeleted': 'Szekcio torolve!',
    'startChat': 'Beszélgetés indítása',
    'loadingGuide': 'A vezető betöltése...',
    'chatPlaceholder': 'Kérdezz valamit erről a helyről...',
    'newConversation': 'Új beszélgetés',
  };

  static const Map<String, String> _en = {
    'appName': 'CampConnect',
    'roleSelectionTitle': 'Who are you?',
    'imAGuide': 'I\'m a Guide',
    'imAKid': 'I\'m a Camper',
    'guideDescription': 'Manage the camp and activities',
    'kidDescription': 'Join the camp with a code',
    'guideLogin': 'Guide Login',
    'createAccount': 'Create Account',
    'welcomeBack': 'Welcome back',
    'signUpSubtitle': 'Sign up to manage your camp',
    'signInSubtitle': 'Sign in to manage your camp',
    'displayName': 'Display name',
    'email': 'Email',
    'password': 'Password',
    'signIn': 'Sign in',
    'hasAccount': 'Already have an account? Sign in',
    'noAccount': 'No account? Create one',
    'forgotPassword': 'Forgot password?',
    'enterEmailForReset': 'Enter your email to reset.',
    'resetEmailSent': 'Password reset email sent.',
    'kidLogin': 'Join the Camp',
    'readyForAdventure': 'Ready for adventure?',
    'enterCampCode': 'Enter the camp code your guide gave you!',
    'campCode': 'Camp Code',
    'askGuideForCode': 'Ask your guide for the code',
    'letsGo': 'Let\'s go!',
    'invalidCode': 'Invalid camp code. Check it and try again.',
    'hey': 'Hi',
    'yourTeam': 'YOUR TEAM',
    'quickStats': 'Quick Stats',
    'teamPoints': 'Team Points',
    'journalEntries': 'Journal Entries',
    'welcome': 'Welcome',
    'guideDashboard': 'Guide Dashboard',
    'sessionOverview': 'Session Overview',
    'activeSession': 'Active Session',
    'noActiveSession': 'No Active Camp Session',
    'createSessionPrompt': 'Create a camp session to get started.',
    'createSession': 'Create Session',
    'quickActions': 'Quick Actions',
    'addPoints': 'Add Points',
    'postAnnouncement': 'Post Announcement',
    'emergencyAlert': 'Emergency Alert',
    'manageCodes': 'Manage Codes',
    'teams': 'Teams',
    'emergency': 'Emergency',
    'emergencyMessage': 'Emergency alert functionality will be available soon. In case of a real emergency, contact the camp director immediately.',
    'send': 'Send',
    'ok': 'OK',
    'somethingWentWrong': 'Something went wrong. Please try again.',
    'retry': 'Retry',
    'noUserFound': 'No user found.',
    'settings': 'Settings',
    'language': 'Language',
    'romanian': 'Romanian',
    'hungarian': 'Hungarian',
    'english': 'English',
    'darkMode': 'Dark Mode',
    'darkThemeActive': 'Dark theme active',
    'lightThemeActive': 'Light theme active',
    'logout': 'Log out',
    'campManagement': 'Camp Management',
    'campSessionManagement': 'Camp Session Management',
    'campSessionManagementSubtitle': 'Create and manage camp sessions',
    'codeManagement': 'Code Management',
    'codeManagementSubtitle': 'Generate and manage access codes',
    'noActivecamp': 'No Active Camp Session',
    'selectCampFirst': 'Please select an active camp session in Camp Session Management.',
    'noCodesYet': 'No codes generated yet',
    'tapToGenerate': 'Tap the button below to generate access codes.',
    'generateCodes': 'Generate Codes',
    'team': 'Team',
    'numberOfCodes': 'Number of Codes',
    'generate': 'Generate',
    'cancel': 'Cancel',
    'used': 'Used',
    'available': 'Available',
    'codes': 'Codes',
    'generatedCodesFor': '{count} codes generated for {team}',
    'home': 'Home',
    'leaderboard': 'Leaderboard',
    'map': 'Map',
    'journal': 'Journal',
    'news': 'News',
    'announcements': 'Announcements',
    'leaderboardComingSoon': 'Leaderboard — Coming soon',
    'pointsManagement': 'Points Management',
    'selectTeam': 'Select Team',
    'pointAmount': 'Point Amount',
    'positiveNegativeHint': 'Positive = add points, Negative = subtract points',
    'reason': 'Reason',
    'reasonHint': 'e.g. Won the relay race',
    'submitPoints': 'Submit Points',
    'pointsAdded': 'Points added successfully!',
    'pointsHistory': 'Points History',
    'noPointsHistory': 'No point changes yet',
    'teamRankings': 'Team Rankings',
    'pts': 'pts',
    'enterPoints': 'Enter the point amount',
    'enterReason': 'Enter a reason',
    'invalidPointAmount': 'Enter a valid number (other than 0)',
    'confirmPoints': 'Confirm Points',
    'pointsUpdated': 'Points have been updated!',
    'rank': 'Rank',
    'yourTeamBadge': 'Your Team',
    'recentActivity': 'Recent Activity',
    'justNow': 'Just now',
    'minutesAgo': 'min ago',
    'hoursAgo': 'hr ago',
    'daysAgo': 'd ago',
    'noTeamsYet': 'No teams yet',
    'noCampSelected': 'Select a camp session',
    'mapComingSoon': 'Map — Coming soon',
    'journalComingSoon': 'Journal — Coming soon',
    'announcementsComingSoon': 'Announcements — Coming soon',
    'emergencyComingSoon': 'Emergency Alerts — Coming soon',
    // Journal
    'newEntry': 'New Entry',
    'editEntry': 'Edit Entry',
    'journalTitle': 'Title',
    'journalBody': 'What happened today?',
    'journalDate': 'Date',
    'journalPhotos': 'Photos',
    'addPhoto': 'Add Photo',
    'removePhoto': 'Remove Photo',
    'saveEntry': 'Save',
    'deleteEntry': 'Delete Entry',
    'deleteEntryConfirm': 'Are you sure you want to delete this journal entry?',
    'entryCreated': 'Entry created successfully!',
    'entryUpdated': 'Entry updated successfully!',
    'entryDeleted': 'Entry deleted!',
    'noJournalEntries': 'No journal entries yet',
    'startWriting': 'Tap the button below to start writing!',
    'enterJournalTitle': 'Enter a title',
    'enterJournalBody': 'Write what happened...',
    'exportPdf': 'Export PDF',
    'exportingPdf': 'Generating PDF...',
    'pdfExported': 'Journal exported successfully!',
    'pdfExportError': 'Export error. Please try again.',
    'myCampJournal': 'My Camp Journal',
    'todayEntry': 'Today\'s entry',
    'emailRequired': 'Email is required',
    'emailInvalid': 'Enter a valid email address',
    'passwordRequired': 'Password is required',
    'passwordTooShort': 'Password must be at least 6 characters',
    'campCodeRequired': 'Camp code is required',
    'campCodeInvalid': 'Invalid code format (expected: CAMP-XXXX)',
    'fieldRequired': 'This field is required',
    'inviteCode': 'Invite code',
    'invalidInviteCode': 'Invalid invite code',
    'joinOrganization': 'Join organization',
    'createOrganization': 'Create organization',
    'organizationName': 'Organization name',
    'organizationCode': 'Organization code',
    'organizationInviteCode': 'Organization invite code',
    'inviteCodeCopied': 'Invite code copied to clipboard!',
    'emailAlreadyInUse': 'This email is already in use',
    'wrongCredentials': 'Wrong email or password',
    'tooManyAttempts': 'Too many attempts. Try again later.',
    'networkError': 'Network error. Check your internet connection.',
    'codeAlreadyUsed': 'This code has already been used.',
    'sessionExpired': 'The camp session has ended.',
    'teamRank': 'Team rank',
    'campSessions': 'Camp Sessions',
    'newSession': 'New Session',
    'createCampSession': 'Create Camp Session',
    'sessionName': 'Session Name',
    'sessionNameHint': 'e.g. Summer Camp 2026',
    'selectStartDate': 'Select the start date',
    'selectEndDate': 'Select the end date',
    'noSessionsYet': 'No camp sessions yet',
    'tapToCreate': 'Tap the button below to create the first session.',
    'active': 'Active',
    'ended': 'Ended',
    'inProgress': 'In progress',
    'activeSessionSet': 'Active session set: ',
    'enterSessionName': 'Enter the session name',
    'selectDates': 'Select start and end dates',
    'selectAtLeastOneTeam': 'Select at least one team',
    'endDateBeforeStart': 'End date cannot be before the start date.',
    'teamName': 'Team name',
    'addTeam': 'Add team',
    'editTeam': 'Edit team',
    'deleteTeamTitle': 'Delete team',
    'cannotDeleteLastTeam': 'Cannot delete the last team.',
    'teamsManagementSubtitle': 'Add, rename, or remove teams',
    'start': 'Start',
    'end': 'End',
    // Announcements
    'announcementsFeed': 'News',
    'announcementManagement': 'Announcement Management',
    'newAnnouncement': 'New Announcement',
    'editAnnouncement': 'Edit Announcement',
    'announcementTitle': 'Title',
    'announcementBody': 'Body',
    'announcementType': 'Type',
    'typeAnnouncement': 'Announcement',
    'typeSchedule': 'Schedule',
    'pinnedAnnouncement': 'Pinned',
    'deleteAnnouncement': 'Delete Announcement',
    'deleteAnnouncementConfirm': 'Are you sure you want to delete this announcement?',
    'delete': 'Delete',
    'announcementCreated': 'Announcement created successfully!',
    'announcementUpdated': 'Announcement updated successfully!',
    'announcementDeleted': 'Announcement deleted!',
    'noAnnouncements': 'No announcements',
    'noAnnouncementsYet': 'No announcements yet. Check back later!',
    'enterTitle': 'Enter the title',
    'enterBody': 'Enter the content',
    'postedBy': 'Posted by',
    'schedule': 'Schedule',
    'scheduleView': 'Schedule View',
    'allAnnouncements': 'All Announcements',
    'pinned': 'Pinned',
    // Emergency
    'emergencyAlertTitle': 'EMERGENCY ALERT',
    'sendEmergencyAlert': 'Send Emergency Alert',
    'emergencyMessageHint': 'e.g. Child injured at the lake, need help',
    'emergencyAlertSent': 'Emergency alert sent!',
    'emergencyHistory': 'Alert History',
    'noEmergencyAlerts': 'No emergency alerts',
    'acknowledge': 'I acknowledge',
    'acknowledged': 'Acknowledged',
    'acknowledgedBy': 'Acknowledged by',
    'emergencyOverlayTitle': 'EMERGENCY',
    'sentBy': 'Sent by',
    'enterEmergencyMessage': 'Enter the emergency message',
    'emergencyConfirm': 'Confirm send',
    'emergencyConfirmMessage': 'This will send an emergency alert to all guides. Continue?',
    // Map & Locations
    'addLocation': 'Add Location',
    'editLocation': 'Edit Location',
    'deleteLocation': 'Delete Location',
    'deleteLocationConfirm': 'Are you sure you want to delete this location?',
    'locationName': 'Location Name',
    'locationDescription': 'Description',
    'locationCategory': 'Category',
    'locationPhoto': 'Photo',
    'locationFacts': 'Facts',
    'locationFunFact': 'Fun Fact',
    'quizQuestion': 'Quiz Question',
    'quizAnswer': 'Quiz Answer',
    'categoryAll': 'All',
    'categoryNature': 'Nature',
    'categoryHistorical': 'Historical',
    'categoryActivity': 'Activity',
    'categoryViewpoint': 'Viewpoint',
    'addFact': 'Add',
    'removeFact': 'Remove',
    'takePhoto': 'Take a Photo',
    'chooseFromGallery': 'Choose from Gallery',
    'saveLocation': 'Save Location',
    'locationCreated': 'Location created successfully!',
    'locationUpdated': 'Location updated successfully!',
    'locationDeleted': 'Location deleted!',
    'noLocationsYet': 'No locations added yet',
    'uploadingPhoto': 'Uploading photo...',
    'savingLocation': 'Saving location...',
    'gpsUnavailable': 'GPS unavailable',
    'locationPermissionDenied': 'Location permission denied',
    'facts': 'Facts',
    'funFact': 'Fun Fact',
    'quiz': 'Quiz',
    'revealAnswer': 'Reveal Answer',
    'myLocation': 'My Location',
    'enterLocationName': 'Enter the location name',
    'enterDescription': 'Enter a description',
    'enterFunFact': 'Enter a fun fact',
    'photoRequired': 'Please add a photo',
    // Master Locations & Knowledge Base
    'mapLocations': 'Map Locations',
    'mapLocationsSubtitle': 'Manage locations and knowledge base',
    'knowledgeBase': 'Knowledge Base',
    'knowledgeBaseDescription': 'Description',
    'knowledgeBaseFacts': 'Facts',
    'knowledgeBaseFunFact': 'Fun Fact',
    'knowledgeBaseDescriptionHint': 'Write a general description of the place...',
    'knowledgeBaseFactsHint': 'Write interesting facts about this place...',
    'knowledgeBaseFunFactHint': 'Write a fun or surprising fact...',
    'knowledgeBaseSaved': 'Knowledge base saved!',
    'noMasterLocations': 'No locations created yet',
    'addToSession': 'Add to Session',
    'selectLocation': 'Select Location',
    'groupPhoto': 'Group Photo',
    'groupPhotoHint': 'Add a group photo at this location',
    'locationAddedToSession': 'Location added to session!',
    'locationAlreadyInSession': 'This location is already in the session',
    'removeFromSession': 'Remove from Session',
    'removeFromSessionConfirm': 'Are you sure you want to remove this location from the session?',
    'locationRemovedFromSession': 'Location removed from session!',
    // Schedule
    'activityName': 'Activity Name',
    'activityDescription': 'Description (optional)',
    'selectDate': 'Select Date',
    'startTimeLabel': 'Start time',
    'endTimeLabel': 'End time',
    'newScheduleEntry': 'New Activity',
    'editScheduleEntry': 'Edit Activity',
    'scheduleEntryCreated': 'Activity added!',
    'scheduleEntryUpdated': 'Activity updated!',
    'scheduleEntryDeleted': 'Activity deleted!',
    'noScheduleEntries': 'No activities scheduled yet',
    'selectDateRequired': 'Select a date',
    'selectTimeRequired': 'Select the time',
    'program': 'Program',
    'whatsYourName': 'What\'s your name?',
    'enterYourName': 'Enter your name',
    'nameHint': 'e.g. Alex',
    'continueButton': 'Continue',
    'nameRequired': 'Please enter your name',
    'selected': 'Selected',
    'deleteSession': 'Delete Session',
    'deleteSessionConfirm': 'Are you sure you want to delete this session? All data will be lost.',
    'sessionDeleted': 'Session deleted!',
    'startChat': 'Start chat',
    'loadingGuide': 'Loading the guide...',
    'chatPlaceholder': 'Ask something about this place...',
    'newConversation': 'New conversation',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ro', 'hu'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations._(locale.languageCode);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
