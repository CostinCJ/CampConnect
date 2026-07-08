import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.g.dart';
import 'app_localizations_hu.g.dart';
import 'app_localizations_ro.g.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.g.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hu'),
    Locale('ro'),
  ];

  /// No description provided for @appName.
  ///
  /// In ro, this message translates to:
  /// **'CampConnect'**
  String get appName;

  /// No description provided for @roleSelectionTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cine ești?'**
  String get roleSelectionTitle;

  /// No description provided for @imAGuide.
  ///
  /// In ro, this message translates to:
  /// **'Sunt Ghid'**
  String get imAGuide;

  /// No description provided for @imAKid.
  ///
  /// In ro, this message translates to:
  /// **'Sunt Copil'**
  String get imAKid;

  /// No description provided for @guideDescription.
  ///
  /// In ro, this message translates to:
  /// **'Am un cod de invitație de la organizator'**
  String get guideDescription;

  /// No description provided for @kidDescription.
  ///
  /// In ro, this message translates to:
  /// **'Alătură-te taberei cu un cod'**
  String get kidDescription;

  /// No description provided for @guideLogin.
  ///
  /// In ro, this message translates to:
  /// **'Autentificare Ghid'**
  String get guideLogin;

  /// No description provided for @createAccount.
  ///
  /// In ro, this message translates to:
  /// **'Creează Cont'**
  String get createAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In ro, this message translates to:
  /// **'Bine ai revenit'**
  String get welcomeBack;

  /// No description provided for @signUpSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Înscrie-te pentru a-ți gestiona tabăra'**
  String get signUpSubtitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Autentifică-te pentru a-ți gestiona tabăra'**
  String get signInSubtitle;

  /// No description provided for @displayName.
  ///
  /// In ro, this message translates to:
  /// **'Nume afișat'**
  String get displayName;

  /// No description provided for @email.
  ///
  /// In ro, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ro, this message translates to:
  /// **'Parolă'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In ro, this message translates to:
  /// **'Autentificare'**
  String get signIn;

  /// No description provided for @hasAccount.
  ///
  /// In ro, this message translates to:
  /// **'Ai deja un cont? Autentifică-te'**
  String get hasAccount;

  /// No description provided for @noAccount.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai cont? Creează Cont'**
  String get noAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In ro, this message translates to:
  /// **'Ai uitat parola?'**
  String get forgotPassword;

  /// No description provided for @enterEmailForReset.
  ///
  /// In ro, this message translates to:
  /// **'Introdu adresa de email pentru resetare.'**
  String get enterEmailForReset;

  /// No description provided for @resetEmailSent.
  ///
  /// In ro, this message translates to:
  /// **'Ți-am trimis un email de resetare.'**
  String get resetEmailSent;

  /// No description provided for @kidLogin.
  ///
  /// In ro, this message translates to:
  /// **'Alătură-te Taberei'**
  String get kidLogin;

  /// No description provided for @readyForAdventure.
  ///
  /// In ro, this message translates to:
  /// **'Pregătit de Aventură?'**
  String get readyForAdventure;

  /// No description provided for @enterCampCode.
  ///
  /// In ro, this message translates to:
  /// **'Introdu codul de tabără primit de la ghid!'**
  String get enterCampCode;

  /// No description provided for @campCode.
  ///
  /// In ro, this message translates to:
  /// **'Cod Tabără'**
  String get campCode;

  /// No description provided for @askGuideForCode.
  ///
  /// In ro, this message translates to:
  /// **'Cere codul ghidului tău'**
  String get askGuideForCode;

  /// No description provided for @letsGo.
  ///
  /// In ro, this message translates to:
  /// **'Hai să mergem!'**
  String get letsGo;

  /// No description provided for @invalidCode.
  ///
  /// In ro, this message translates to:
  /// **'Cod de tabără invalid. Verifică și încearcă din nou.'**
  String get invalidCode;

  /// No description provided for @hey.
  ///
  /// In ro, this message translates to:
  /// **'Salut'**
  String get hey;

  /// No description provided for @yourTeam.
  ///
  /// In ro, this message translates to:
  /// **'ECHIPA TA'**
  String get yourTeam;

  /// No description provided for @quickStats.
  ///
  /// In ro, this message translates to:
  /// **'Statistici Rapide'**
  String get quickStats;

  /// No description provided for @teamPoints.
  ///
  /// In ro, this message translates to:
  /// **'Puncte Echipă'**
  String get teamPoints;

  /// No description provided for @pointsShort.
  ///
  /// In ro, this message translates to:
  /// **'puncte'**
  String get pointsShort;

  /// No description provided for @defaultTeamRed.
  ///
  /// In ro, this message translates to:
  /// **'Roșu'**
  String get defaultTeamRed;

  /// No description provided for @defaultTeamBlue.
  ///
  /// In ro, this message translates to:
  /// **'Albastru'**
  String get defaultTeamBlue;

  /// No description provided for @defaultTeamGreen.
  ///
  /// In ro, this message translates to:
  /// **'Verde'**
  String get defaultTeamGreen;

  /// No description provided for @defaultTeamYellow.
  ///
  /// In ro, this message translates to:
  /// **'Galben'**
  String get defaultTeamYellow;

  /// No description provided for @teamColorPink.
  ///
  /// In ro, this message translates to:
  /// **'Roz'**
  String get teamColorPink;

  /// No description provided for @teamColorPurple.
  ///
  /// In ro, this message translates to:
  /// **'Mov'**
  String get teamColorPurple;

  /// No description provided for @teamColorIndigo.
  ///
  /// In ro, this message translates to:
  /// **'Indigo'**
  String get teamColorIndigo;

  /// No description provided for @teamColorCyan.
  ///
  /// In ro, this message translates to:
  /// **'Cian'**
  String get teamColorCyan;

  /// No description provided for @teamColorTeal.
  ///
  /// In ro, this message translates to:
  /// **'Turcoaz'**
  String get teamColorTeal;

  /// No description provided for @teamColorLime.
  ///
  /// In ro, this message translates to:
  /// **'Lime'**
  String get teamColorLime;

  /// No description provided for @teamColorOrange.
  ///
  /// In ro, this message translates to:
  /// **'Portocaliu'**
  String get teamColorOrange;

  /// No description provided for @teamColorBrown.
  ///
  /// In ro, this message translates to:
  /// **'Maro'**
  String get teamColorBrown;

  /// No description provided for @teamColorGrey.
  ///
  /// In ro, this message translates to:
  /// **'Gri'**
  String get teamColorGrey;

  /// No description provided for @journalEntries.
  ///
  /// In ro, this message translates to:
  /// **'Intrări Jurnal'**
  String get journalEntries;

  /// No description provided for @welcome.
  ///
  /// In ro, this message translates to:
  /// **'Bine ai venit'**
  String get welcome;

  /// No description provided for @guideDashboard.
  ///
  /// In ro, this message translates to:
  /// **'Panou Ghid'**
  String get guideDashboard;

  /// No description provided for @sessionOverview.
  ///
  /// In ro, this message translates to:
  /// **'Prezentare Sesiune'**
  String get sessionOverview;

  /// No description provided for @activeSession.
  ///
  /// In ro, this message translates to:
  /// **'Sesiune Activă'**
  String get activeSession;

  /// No description provided for @noActiveSession.
  ///
  /// In ro, this message translates to:
  /// **'Nicio Sesiune de Tabără Activă'**
  String get noActiveSession;

  /// No description provided for @createSessionPrompt.
  ///
  /// In ro, this message translates to:
  /// **'Creează o sesiune de tabără pentru a începe.'**
  String get createSessionPrompt;

  /// No description provided for @createSession.
  ///
  /// In ro, this message translates to:
  /// **'Creează Sesiune'**
  String get createSession;

  /// No description provided for @quickActions.
  ///
  /// In ro, this message translates to:
  /// **'Acțiuni Rapide'**
  String get quickActions;

  /// No description provided for @addPoints.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă Puncte'**
  String get addPoints;

  /// No description provided for @postAnnouncement.
  ///
  /// In ro, this message translates to:
  /// **'Postează Anunț'**
  String get postAnnouncement;

  /// No description provided for @emergencyAlert.
  ///
  /// In ro, this message translates to:
  /// **'Alertă de Urgență'**
  String get emergencyAlert;

  /// No description provided for @manageCodes.
  ///
  /// In ro, this message translates to:
  /// **'Gestionează Coduri'**
  String get manageCodes;

  /// No description provided for @teams.
  ///
  /// In ro, this message translates to:
  /// **'Echipe'**
  String get teams;

  /// No description provided for @emergency.
  ///
  /// In ro, this message translates to:
  /// **'Urgență'**
  String get emergency;

  /// No description provided for @emergencyMessage.
  ///
  /// In ro, this message translates to:
  /// **'Funcționalitatea alertelor de urgență va fi disponibilă în curând. În caz de urgență reală, contactează imediat directorul taberei.'**
  String get emergencyMessage;

  /// No description provided for @send.
  ///
  /// In ro, this message translates to:
  /// **'Trimite'**
  String get send;

  /// No description provided for @ok.
  ///
  /// In ro, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @somethingWentWrong.
  ///
  /// In ro, this message translates to:
  /// **'Ceva nu a mers bine. Te rugăm încearcă din nou.'**
  String get somethingWentWrong;

  /// No description provided for @weakPassword.
  ///
  /// In ro, this message translates to:
  /// **'Parola este prea slabă — alege cel puțin 8 caractere.'**
  String get weakPassword;

  /// No description provided for @retry.
  ///
  /// In ro, this message translates to:
  /// **'Reîncearcă'**
  String get retry;

  /// No description provided for @noUserFound.
  ///
  /// In ro, this message translates to:
  /// **'Niciun utilizator găsit.'**
  String get noUserFound;

  /// No description provided for @settings.
  ///
  /// In ro, this message translates to:
  /// **'Setări'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In ro, this message translates to:
  /// **'Limbă'**
  String get language;

  /// No description provided for @romanian.
  ///
  /// In ro, this message translates to:
  /// **'Română'**
  String get romanian;

  /// No description provided for @hungarian.
  ///
  /// In ro, this message translates to:
  /// **'Maghiară'**
  String get hungarian;

  /// No description provided for @english.
  ///
  /// In ro, this message translates to:
  /// **'Engleză'**
  String get english;

  /// No description provided for @darkMode.
  ///
  /// In ro, this message translates to:
  /// **'Mod Întunecat'**
  String get darkMode;

  /// No description provided for @darkThemeActive.
  ///
  /// In ro, this message translates to:
  /// **'Temă întunecată activă'**
  String get darkThemeActive;

  /// No description provided for @lightThemeActive.
  ///
  /// In ro, this message translates to:
  /// **'Temă luminoasă activă'**
  String get lightThemeActive;

  /// No description provided for @logout.
  ///
  /// In ro, this message translates to:
  /// **'Deconectare'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In ro, this message translates to:
  /// **'Șterge contul'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In ro, this message translates to:
  /// **'Această acțiune îți șterge definitiv contul. Dacă deții organizația, sunt șterse și toate taberele ei.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteMyData.
  ///
  /// In ro, this message translates to:
  /// **'Șterge-mi datele'**
  String get deleteMyData;

  /// No description provided for @kidLogoutConfirmTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ești sigur?'**
  String get kidLogoutConfirmTitle;

  /// No description provided for @kidLogoutConfirmMessage.
  ///
  /// In ro, this message translates to:
  /// **'După deconectare vei avea nevoie de un cod nou de la ghidul tău ca să te conectezi din nou.'**
  String get kidLogoutConfirmMessage;

  /// No description provided for @orgHasMembersError.
  ///
  /// In ro, this message translates to:
  /// **'Scoate mai întâi ceilalți ghizi din organizație înainte să îți ștergi contul.'**
  String get orgHasMembersError;

  /// No description provided for @privacyPolicy.
  ///
  /// In ro, this message translates to:
  /// **'Politica de confidențialitate'**
  String get privacyPolicy;

  /// No description provided for @byContinuingYouAgreeToPrivacyPolicy.
  ///
  /// In ro, this message translates to:
  /// **'Continuând, ești de acord cu Politica de confidențialitate'**
  String get byContinuingYouAgreeToPrivacyPolicy;

  /// No description provided for @campManagement.
  ///
  /// In ro, this message translates to:
  /// **'Gestionare Tabără'**
  String get campManagement;

  /// No description provided for @campSessionManagement.
  ///
  /// In ro, this message translates to:
  /// **'Gestionare Sesiuni Tabără'**
  String get campSessionManagement;

  /// No description provided for @campSessionManagementSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Creează și gestionează sesiunile de tabără'**
  String get campSessionManagementSubtitle;

  /// No description provided for @codeManagement.
  ///
  /// In ro, this message translates to:
  /// **'Gestionare Coduri'**
  String get codeManagement;

  /// No description provided for @codeManagementSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Generează și gestionează codurile de acces'**
  String get codeManagementSubtitle;

  /// No description provided for @noActivecamp.
  ///
  /// In ro, this message translates to:
  /// **'Nicio Sesiune de Tabără Activă'**
  String get noActivecamp;

  /// No description provided for @selectCampFirst.
  ///
  /// In ro, this message translates to:
  /// **'Te rugăm selectează o sesiune de tabără activă din Gestionare Sesiuni Tabără.'**
  String get selectCampFirst;

  /// No description provided for @noCodesYet.
  ///
  /// In ro, this message translates to:
  /// **'Niciun cod generat încă'**
  String get noCodesYet;

  /// No description provided for @tapToGenerate.
  ///
  /// In ro, this message translates to:
  /// **'Apasă butonul de mai jos pentru a genera coduri de acces.'**
  String get tapToGenerate;

  /// No description provided for @generateCodes.
  ///
  /// In ro, this message translates to:
  /// **'Generează Coduri'**
  String get generateCodes;

  /// No description provided for @team.
  ///
  /// In ro, this message translates to:
  /// **'Echipă'**
  String get team;

  /// No description provided for @numberOfCodes.
  ///
  /// In ro, this message translates to:
  /// **'Număr de Coduri'**
  String get numberOfCodes;

  /// No description provided for @generate.
  ///
  /// In ro, this message translates to:
  /// **'Generează'**
  String get generate;

  /// No description provided for @cancel.
  ///
  /// In ro, this message translates to:
  /// **'Anulează'**
  String get cancel;

  /// No description provided for @used.
  ///
  /// In ro, this message translates to:
  /// **'Folosit'**
  String get used;

  /// No description provided for @available.
  ///
  /// In ro, this message translates to:
  /// **'Disponibil'**
  String get available;

  /// No description provided for @generatedCodesFor.
  ///
  /// In ro, this message translates to:
  /// **'{count} coduri generate pentru {team}'**
  String generatedCodesFor(int count, String team);

  /// No description provided for @home.
  ///
  /// In ro, this message translates to:
  /// **'Acasă'**
  String get home;

  /// No description provided for @leaderboard.
  ///
  /// In ro, this message translates to:
  /// **'Clasament'**
  String get leaderboard;

  /// No description provided for @map.
  ///
  /// In ro, this message translates to:
  /// **'Hartă'**
  String get map;

  /// No description provided for @journal.
  ///
  /// In ro, this message translates to:
  /// **'Jurnal'**
  String get journal;

  /// No description provided for @news.
  ///
  /// In ro, this message translates to:
  /// **'Noutăți'**
  String get news;

  /// No description provided for @announcements.
  ///
  /// In ro, this message translates to:
  /// **'Anunțuri'**
  String get announcements;

  /// No description provided for @leaderboardComingSoon.
  ///
  /// In ro, this message translates to:
  /// **'Clasament - În curând'**
  String get leaderboardComingSoon;

  /// No description provided for @pointsManagement.
  ///
  /// In ro, this message translates to:
  /// **'Gestionare Puncte'**
  String get pointsManagement;

  /// No description provided for @selectTeam.
  ///
  /// In ro, this message translates to:
  /// **'Selectează Echipa'**
  String get selectTeam;

  /// No description provided for @pointAmount.
  ///
  /// In ro, this message translates to:
  /// **'Număr de Puncte'**
  String get pointAmount;

  /// No description provided for @positiveNegativeHint.
  ///
  /// In ro, this message translates to:
  /// **'Pozitiv = adaugă puncte, Negativ = scade puncte'**
  String get positiveNegativeHint;

  /// No description provided for @reason.
  ///
  /// In ro, this message translates to:
  /// **'Motiv'**
  String get reason;

  /// No description provided for @reasonHint.
  ///
  /// In ro, this message translates to:
  /// **'ex. A câștigat cursa de ștafetă'**
  String get reasonHint;

  /// No description provided for @submitPoints.
  ///
  /// In ro, this message translates to:
  /// **'Trimite Puncte'**
  String get submitPoints;

  /// No description provided for @pointsAdded.
  ///
  /// In ro, this message translates to:
  /// **'Puncte adăugate cu succes!'**
  String get pointsAdded;

  /// No description provided for @pointsHistory.
  ///
  /// In ro, this message translates to:
  /// **'Istoric Puncte'**
  String get pointsHistory;

  /// No description provided for @noPointsHistory.
  ///
  /// In ro, this message translates to:
  /// **'Nicio modificare de puncte încă'**
  String get noPointsHistory;

  /// No description provided for @teamRankings.
  ///
  /// In ro, this message translates to:
  /// **'Clasament Echipe'**
  String get teamRankings;

  /// No description provided for @pts.
  ///
  /// In ro, this message translates to:
  /// **'pct'**
  String get pts;

  /// No description provided for @enterPoints.
  ///
  /// In ro, this message translates to:
  /// **'Introdu numărul de puncte'**
  String get enterPoints;

  /// No description provided for @enterReason.
  ///
  /// In ro, this message translates to:
  /// **'Introdu un motiv'**
  String get enterReason;

  /// No description provided for @invalidPointAmount.
  ///
  /// In ro, this message translates to:
  /// **'Introdu un număr valid (diferit de 0)'**
  String get invalidPointAmount;

  /// No description provided for @confirmPoints.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă Puncte'**
  String get confirmPoints;

  /// No description provided for @pointsUpdated.
  ///
  /// In ro, this message translates to:
  /// **'Punctele au fost actualizate!'**
  String get pointsUpdated;

  /// No description provided for @rank.
  ///
  /// In ro, this message translates to:
  /// **'Loc'**
  String get rank;

  /// No description provided for @yourTeamBadge.
  ///
  /// In ro, this message translates to:
  /// **'Echipa Ta'**
  String get yourTeamBadge;

  /// No description provided for @recentActivity.
  ///
  /// In ro, this message translates to:
  /// **'Activitate Recentă'**
  String get recentActivity;

  /// No description provided for @justNow.
  ///
  /// In ro, this message translates to:
  /// **'chiar acum'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{acum {count} minut} other{acum {count} minute}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{acum {count} oră} other{acum {count} ore}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{acum {count} zi} other{acum {count} zile}}'**
  String daysAgo(int count);

  /// No description provided for @noTeamsYet.
  ///
  /// In ro, this message translates to:
  /// **'Nicio echipă încă'**
  String get noTeamsYet;

  /// No description provided for @noCampSelected.
  ///
  /// In ro, this message translates to:
  /// **'Selectează o sesiune de tabără'**
  String get noCampSelected;

  /// No description provided for @mapComingSoon.
  ///
  /// In ro, this message translates to:
  /// **'Hartă - În curând'**
  String get mapComingSoon;

  /// No description provided for @journalComingSoon.
  ///
  /// In ro, this message translates to:
  /// **'Jurnal - În curând'**
  String get journalComingSoon;

  /// No description provided for @announcementsComingSoon.
  ///
  /// In ro, this message translates to:
  /// **'Anunțuri - În curând'**
  String get announcementsComingSoon;

  /// No description provided for @emergencyComingSoon.
  ///
  /// In ro, this message translates to:
  /// **'Alerte de Urgență - În curând'**
  String get emergencyComingSoon;

  /// No description provided for @newEntry.
  ///
  /// In ro, this message translates to:
  /// **'Intrare Nouă'**
  String get newEntry;

  /// No description provided for @editEntry.
  ///
  /// In ro, this message translates to:
  /// **'Editează Intrare'**
  String get editEntry;

  /// No description provided for @journalTitle.
  ///
  /// In ro, this message translates to:
  /// **'Titlu'**
  String get journalTitle;

  /// No description provided for @journalBody.
  ///
  /// In ro, this message translates to:
  /// **'Ce s-a întâmplat azi?'**
  String get journalBody;

  /// No description provided for @journalDate.
  ///
  /// In ro, this message translates to:
  /// **'Data'**
  String get journalDate;

  /// No description provided for @journalPhotos.
  ///
  /// In ro, this message translates to:
  /// **'Fotografii'**
  String get journalPhotos;

  /// No description provided for @addPhoto.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă Fotografie'**
  String get addPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In ro, this message translates to:
  /// **'Șterge Fotografia'**
  String get removePhoto;

  /// No description provided for @saveEntry.
  ///
  /// In ro, this message translates to:
  /// **'Salvează'**
  String get saveEntry;

  /// No description provided for @deleteEntry.
  ///
  /// In ro, this message translates to:
  /// **'Șterge Intrarea'**
  String get deleteEntry;

  /// No description provided for @deleteEntryConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Ești sigur că vrei să ștergi această intrare din jurnal?'**
  String get deleteEntryConfirm;

  /// No description provided for @entryCreated.
  ///
  /// In ro, this message translates to:
  /// **'Intrare creată cu succes!'**
  String get entryCreated;

  /// No description provided for @entryUpdated.
  ///
  /// In ro, this message translates to:
  /// **'Intrare actualizată cu succes!'**
  String get entryUpdated;

  /// No description provided for @photoRemoved.
  ///
  /// In ro, this message translates to:
  /// **'Poză eliminată'**
  String get photoRemoved;

  /// No description provided for @undo.
  ///
  /// In ro, this message translates to:
  /// **'Anulează'**
  String get undo;

  /// No description provided for @entryDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Intrare ștearsă!'**
  String get entryDeleted;

  /// No description provided for @noJournalEntries.
  ///
  /// In ro, this message translates to:
  /// **'Nicio intrare în jurnal încă'**
  String get noJournalEntries;

  /// No description provided for @startWriting.
  ///
  /// In ro, this message translates to:
  /// **'Apasă butonul de mai jos pentru a începe să scrii!'**
  String get startWriting;

  /// No description provided for @enterJournalTitle.
  ///
  /// In ro, this message translates to:
  /// **'Introdu un titlu'**
  String get enterJournalTitle;

  /// No description provided for @enterJournalBody.
  ///
  /// In ro, this message translates to:
  /// **'Scrie ce s-a întâmplat...'**
  String get enterJournalBody;

  /// No description provided for @exportPdf.
  ///
  /// In ro, this message translates to:
  /// **'Exportă PDF'**
  String get exportPdf;

  /// No description provided for @exportingPdf.
  ///
  /// In ro, this message translates to:
  /// **'Se generează PDF-ul...'**
  String get exportingPdf;

  /// No description provided for @pdfExported.
  ///
  /// In ro, this message translates to:
  /// **'Jurnal exportat cu succes!'**
  String get pdfExported;

  /// No description provided for @pdfExportError.
  ///
  /// In ro, this message translates to:
  /// **'Eroare la export. Te rugăm încearcă din nou.'**
  String get pdfExportError;

  /// No description provided for @myCampJournal.
  ///
  /// In ro, this message translates to:
  /// **'Jurnalul Meu de Tabără'**
  String get myCampJournal;

  /// No description provided for @todayEntry.
  ///
  /// In ro, this message translates to:
  /// **'Intrare de azi'**
  String get todayEntry;

  /// No description provided for @emailRequired.
  ///
  /// In ro, this message translates to:
  /// **'Email-ul este obligatoriu'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In ro, this message translates to:
  /// **'Introdu o adresă de email validă'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In ro, this message translates to:
  /// **'Parola este obligatorie'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In ro, this message translates to:
  /// **'Parola trebuie să aibă cel puțin 8 caractere'**
  String get passwordTooShort;

  /// No description provided for @campCodeRequired.
  ///
  /// In ro, this message translates to:
  /// **'Codul de tabără este obligatoriu'**
  String get campCodeRequired;

  /// No description provided for @campCodeInvalid.
  ///
  /// In ro, this message translates to:
  /// **'Format cod invalid (așteptat: CAMP-XXXX)'**
  String get campCodeInvalid;

  /// No description provided for @fieldRequired.
  ///
  /// In ro, this message translates to:
  /// **'Acest câmp este obligatoriu'**
  String get fieldRequired;

  /// No description provided for @inviteCode.
  ///
  /// In ro, this message translates to:
  /// **'Cod de invitație'**
  String get inviteCode;

  /// No description provided for @invalidInviteCode.
  ///
  /// In ro, this message translates to:
  /// **'Cod de invitație invalid'**
  String get invalidInviteCode;

  /// No description provided for @joinOrganization.
  ///
  /// In ro, this message translates to:
  /// **'Alătură-te unei organizații'**
  String get joinOrganization;

  /// No description provided for @createOrganization.
  ///
  /// In ro, this message translates to:
  /// **'Creează o organizație'**
  String get createOrganization;

  /// No description provided for @organizationName.
  ///
  /// In ro, this message translates to:
  /// **'Numele organizației'**
  String get organizationName;

  /// No description provided for @organizationCode.
  ///
  /// In ro, this message translates to:
  /// **'Codul organizației'**
  String get organizationCode;

  /// No description provided for @organizationInviteCode.
  ///
  /// In ro, this message translates to:
  /// **'Codul de invitație al organizației'**
  String get organizationInviteCode;

  /// No description provided for @campCodePrefix.
  ///
  /// In ro, this message translates to:
  /// **'Prefixul codurilor de tabără'**
  String get campCodePrefix;

  /// No description provided for @campCodePrefixDesc.
  ///
  /// In ro, this message translates to:
  /// **'Codurile taberelor tale încep cu acest prefix. Schimbă-l ca să fie unic.'**
  String get campCodePrefixDesc;

  /// No description provided for @campCodePrefixInvalid.
  ///
  /// In ro, this message translates to:
  /// **'Folosește 2–8 litere sau cifre.'**
  String get campCodePrefixInvalid;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In ro, this message translates to:
  /// **'Cod copiat în clipboard!'**
  String get inviteCodeCopied;

  /// No description provided for @setupCampTile.
  ///
  /// In ro, this message translates to:
  /// **'Îmi organizez tabăra'**
  String get setupCampTile;

  /// No description provided for @setupCampDescription.
  ///
  /// In ro, this message translates to:
  /// **'Creează-ți organizația și administrează-ți taberele'**
  String get setupCampDescription;

  /// No description provided for @setupYourOrg.
  ///
  /// In ro, this message translates to:
  /// **'Configurează-ți organizația taberei'**
  String get setupYourOrg;

  /// No description provided for @joinYourOrg.
  ///
  /// In ro, this message translates to:
  /// **'Alătură-te organizației tale'**
  String get joinYourOrg;

  /// No description provided for @switchToJoin.
  ///
  /// In ro, this message translates to:
  /// **'Ai deja un cod de invitație?'**
  String get switchToJoin;

  /// No description provided for @switchToCreate.
  ///
  /// In ro, this message translates to:
  /// **'Vrei să creezi o organizație nouă?'**
  String get switchToCreate;

  /// No description provided for @day0Title.
  ///
  /// In ro, this message translates to:
  /// **'Pune tabăra în mișcare'**
  String get day0Title;

  /// No description provided for @stepCreateSession.
  ///
  /// In ro, this message translates to:
  /// **'Creează prima sesiune de tabără'**
  String get stepCreateSession;

  /// No description provided for @stepInviteGuides.
  ///
  /// In ro, this message translates to:
  /// **'Invită-ți ghizii'**
  String get stepInviteGuides;

  /// No description provided for @stepGenerateCodes.
  ///
  /// In ro, this message translates to:
  /// **'Generează coduri pentru copii'**
  String get stepGenerateCodes;

  /// No description provided for @shareInviteMessage.
  ///
  /// In ro, this message translates to:
  /// **'Alătură-te {orgName} pe CampConnect! Deschide aplicația și înregistrează-te ca ghid cu codul de invitație {inviteCode}.'**
  String shareInviteMessage(String orgName, String inviteCode);

  /// No description provided for @myOrganization.
  ///
  /// In ro, this message translates to:
  /// **'Taberele mele'**
  String get myOrganization;

  /// No description provided for @members.
  ///
  /// In ro, this message translates to:
  /// **'Membri'**
  String get members;

  /// No description provided for @ownerRole.
  ///
  /// In ro, this message translates to:
  /// **'Proprietar'**
  String get ownerRole;

  /// No description provided for @guideRole.
  ///
  /// In ro, this message translates to:
  /// **'Ghid'**
  String get guideRole;

  /// No description provided for @removeGuide.
  ///
  /// In ro, this message translates to:
  /// **'Elimină ghidul'**
  String get removeGuide;

  /// No description provided for @removeGuideConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Elimini {name} din organizație? Va pierde imediat accesul.'**
  String removeGuideConfirm(String name);

  /// No description provided for @memberRemoved.
  ///
  /// In ro, this message translates to:
  /// **'Ghid eliminat'**
  String get memberRemoved;

  /// No description provided for @rotateInviteCodeAction.
  ///
  /// In ro, this message translates to:
  /// **'Generează un cod de invitație nou'**
  String get rotateInviteCodeAction;

  /// No description provided for @rotateInviteCodeConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Codul actual nu va mai funcționa. Ghizii deja membri nu sunt afectați.'**
  String get rotateInviteCodeConfirm;

  /// No description provided for @codeRotated.
  ///
  /// In ro, this message translates to:
  /// **'Cod de invitație nou generat'**
  String get codeRotated;

  /// No description provided for @notOrgOwner.
  ///
  /// In ro, this message translates to:
  /// **'Doar proprietarul organizației poate face asta'**
  String get notOrgOwner;

  /// No description provided for @share.
  ///
  /// In ro, this message translates to:
  /// **'Trimite'**
  String get share;

  /// No description provided for @dismiss.
  ///
  /// In ro, this message translates to:
  /// **'Închide'**
  String get dismiss;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In ro, this message translates to:
  /// **'Acest email este deja folosit'**
  String get emailAlreadyInUse;

  /// No description provided for @wrongCredentials.
  ///
  /// In ro, this message translates to:
  /// **'Email sau parolă incorectă'**
  String get wrongCredentials;

  /// No description provided for @tooManyAttempts.
  ///
  /// In ro, this message translates to:
  /// **'Prea multe încercări. Încearcă din nou mai târziu.'**
  String get tooManyAttempts;

  /// No description provided for @networkError.
  ///
  /// In ro, this message translates to:
  /// **'Eroare de rețea. Verifică conexiunea la internet.'**
  String get networkError;

  /// No description provided for @codeAlreadyUsed.
  ///
  /// In ro, this message translates to:
  /// **'Acest cod a fost deja folosit.'**
  String get codeAlreadyUsed;

  /// No description provided for @sessionExpired.
  ///
  /// In ro, this message translates to:
  /// **'Sesiunea de tabără s-a încheiat.'**
  String get sessionExpired;

  /// No description provided for @teamRank.
  ///
  /// In ro, this message translates to:
  /// **'Locul echipei'**
  String get teamRank;

  /// No description provided for @campSessions.
  ///
  /// In ro, this message translates to:
  /// **'Sesiuni Tabără'**
  String get campSessions;

  /// No description provided for @newSession.
  ///
  /// In ro, this message translates to:
  /// **'Sesiune Nouă'**
  String get newSession;

  /// No description provided for @editSession.
  ///
  /// In ro, this message translates to:
  /// **'Editează tabăra'**
  String get editSession;

  /// No description provided for @saveChanges.
  ///
  /// In ro, this message translates to:
  /// **'Salvează'**
  String get saveChanges;

  /// No description provided for @createCampSession.
  ///
  /// In ro, this message translates to:
  /// **'Creează Sesiune Tabără'**
  String get createCampSession;

  /// No description provided for @sessionName.
  ///
  /// In ro, this message translates to:
  /// **'Numele Sesiunii'**
  String get sessionName;

  /// No description provided for @sessionNameHint.
  ///
  /// In ro, this message translates to:
  /// **'ex. Tabăra de Vară 2026'**
  String get sessionNameHint;

  /// No description provided for @selectStartDate.
  ///
  /// In ro, this message translates to:
  /// **'Selectează data de început'**
  String get selectStartDate;

  /// No description provided for @selectEndDate.
  ///
  /// In ro, this message translates to:
  /// **'Selectează data de sfârșit'**
  String get selectEndDate;

  /// No description provided for @noSessionsYet.
  ///
  /// In ro, this message translates to:
  /// **'Nicio sesiune de tabără încă'**
  String get noSessionsYet;

  /// No description provided for @tapToCreate.
  ///
  /// In ro, this message translates to:
  /// **'Apasă butonul de mai jos pentru a crea prima sesiune.'**
  String get tapToCreate;

  /// No description provided for @active.
  ///
  /// In ro, this message translates to:
  /// **'Activă'**
  String get active;

  /// No description provided for @ended.
  ///
  /// In ro, this message translates to:
  /// **'Încheiată'**
  String get ended;

  /// No description provided for @inProgress.
  ///
  /// In ro, this message translates to:
  /// **'În desfășurare'**
  String get inProgress;

  /// No description provided for @activeSessionSet.
  ///
  /// In ro, this message translates to:
  /// **'Sesiunea activă setată: '**
  String get activeSessionSet;

  /// No description provided for @enterSessionName.
  ///
  /// In ro, this message translates to:
  /// **'Introdu numele sesiunii'**
  String get enterSessionName;

  /// No description provided for @selectDates.
  ///
  /// In ro, this message translates to:
  /// **'Selectează datele de început și sfârșit'**
  String get selectDates;

  /// No description provided for @selectAtLeastOneTeam.
  ///
  /// In ro, this message translates to:
  /// **'Selectează cel puțin o echipă'**
  String get selectAtLeastOneTeam;

  /// No description provided for @endDateBeforeStart.
  ///
  /// In ro, this message translates to:
  /// **'Data de sfârșit nu poate fi înaintea celei de început.'**
  String get endDateBeforeStart;

  /// No description provided for @teamName.
  ///
  /// In ro, this message translates to:
  /// **'Numele echipei'**
  String get teamName;

  /// No description provided for @addTeam.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă echipă'**
  String get addTeam;

  /// No description provided for @editTeam.
  ///
  /// In ro, this message translates to:
  /// **'Editează echipa'**
  String get editTeam;

  /// No description provided for @deleteTeamTitle.
  ///
  /// In ro, this message translates to:
  /// **'Șterge echipa'**
  String get deleteTeamTitle;

  /// No description provided for @cannotDeleteLastTeam.
  ///
  /// In ro, this message translates to:
  /// **'Nu poți șterge ultima echipă.'**
  String get cannotDeleteLastTeam;

  /// No description provided for @teamsManagementSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă, redenumește sau șterge echipe'**
  String get teamsManagementSubtitle;

  /// No description provided for @start.
  ///
  /// In ro, this message translates to:
  /// **'Început'**
  String get start;

  /// No description provided for @end.
  ///
  /// In ro, this message translates to:
  /// **'Sfârșit'**
  String get end;

  /// No description provided for @announcementsFeed.
  ///
  /// In ro, this message translates to:
  /// **'Noutăți'**
  String get announcementsFeed;

  /// No description provided for @announcementManagement.
  ///
  /// In ro, this message translates to:
  /// **'Gestionare Anunțuri'**
  String get announcementManagement;

  /// No description provided for @newAnnouncement.
  ///
  /// In ro, this message translates to:
  /// **'Anunț Nou'**
  String get newAnnouncement;

  /// No description provided for @editAnnouncement.
  ///
  /// In ro, this message translates to:
  /// **'Editează Anunț'**
  String get editAnnouncement;

  /// No description provided for @announcementTitle.
  ///
  /// In ro, this message translates to:
  /// **'Titlu'**
  String get announcementTitle;

  /// No description provided for @announcementBody.
  ///
  /// In ro, this message translates to:
  /// **'Conținut'**
  String get announcementBody;

  /// No description provided for @announcementTemplates.
  ///
  /// In ro, this message translates to:
  /// **'Șabloane de anunțuri'**
  String get announcementTemplates;

  /// No description provided for @announcementTemplatesSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Mesaje pre-scrise pe care le poți trimite'**
  String get announcementTemplatesSubtitle;

  /// No description provided for @useTemplate.
  ///
  /// In ro, this message translates to:
  /// **'Folosește un șablon'**
  String get useTemplate;

  /// No description provided for @newTemplate.
  ///
  /// In ro, this message translates to:
  /// **'Șablon nou'**
  String get newTemplate;

  /// No description provided for @editTemplate.
  ///
  /// In ro, this message translates to:
  /// **'Editează șablonul'**
  String get editTemplate;

  /// No description provided for @deleteTemplate.
  ///
  /// In ro, this message translates to:
  /// **'Șterge șablonul'**
  String get deleteTemplate;

  /// No description provided for @deleteTemplateConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Ștergi acest șablon?'**
  String get deleteTemplateConfirm;

  /// No description provided for @templateDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Șablon șters'**
  String get templateDeleted;

  /// No description provided for @noTemplatesYet.
  ///
  /// In ro, this message translates to:
  /// **'Niciun șablon încă'**
  String get noTemplatesYet;

  /// No description provided for @templateLanguageHint.
  ///
  /// In ro, this message translates to:
  /// **'Completează fiecare limbă ca să funcționeze indiferent în ce limbă trimiți.'**
  String get templateLanguageHint;

  /// No description provided for @templateNeedsContent.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă un titlu și un conținut în cel puțin o limbă.'**
  String get templateNeedsContent;

  /// No description provided for @announcementType.
  ///
  /// In ro, this message translates to:
  /// **'Tip'**
  String get announcementType;

  /// No description provided for @typeAnnouncement.
  ///
  /// In ro, this message translates to:
  /// **'Anunț'**
  String get typeAnnouncement;

  /// No description provided for @typeSchedule.
  ///
  /// In ro, this message translates to:
  /// **'Program'**
  String get typeSchedule;

  /// No description provided for @pinnedAnnouncement.
  ///
  /// In ro, this message translates to:
  /// **'Fixat în top'**
  String get pinnedAnnouncement;

  /// No description provided for @deleteAnnouncement.
  ///
  /// In ro, this message translates to:
  /// **'Șterge Anunț'**
  String get deleteAnnouncement;

  /// No description provided for @deleteAnnouncementConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Ești sigur că vrei să ștergi acest anunț?'**
  String get deleteAnnouncementConfirm;

  /// No description provided for @delete.
  ///
  /// In ro, this message translates to:
  /// **'Șterge'**
  String get delete;

  /// No description provided for @announcementCreated.
  ///
  /// In ro, this message translates to:
  /// **'Anunț creat cu succes!'**
  String get announcementCreated;

  /// No description provided for @announcementUpdated.
  ///
  /// In ro, this message translates to:
  /// **'Anunț actualizat cu succes!'**
  String get announcementUpdated;

  /// No description provided for @announcementDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Anunț șters!'**
  String get announcementDeleted;

  /// No description provided for @noAnnouncements.
  ///
  /// In ro, this message translates to:
  /// **'Niciun anunț'**
  String get noAnnouncements;

  /// No description provided for @noAnnouncementsYet.
  ///
  /// In ro, this message translates to:
  /// **'Niciun anunț încă. Revino mai târziu!'**
  String get noAnnouncementsYet;

  /// No description provided for @enterTitle.
  ///
  /// In ro, this message translates to:
  /// **'Introdu titlul'**
  String get enterTitle;

  /// No description provided for @enterBody.
  ///
  /// In ro, this message translates to:
  /// **'Introdu conținutul'**
  String get enterBody;

  /// No description provided for @postedBy.
  ///
  /// In ro, this message translates to:
  /// **'Postat de'**
  String get postedBy;

  /// No description provided for @schedule.
  ///
  /// In ro, this message translates to:
  /// **'Program'**
  String get schedule;

  /// No description provided for @scheduleView.
  ///
  /// In ro, this message translates to:
  /// **'Vizualizare Program'**
  String get scheduleView;

  /// No description provided for @allAnnouncements.
  ///
  /// In ro, this message translates to:
  /// **'Toate Anunțurile'**
  String get allAnnouncements;

  /// No description provided for @pinned.
  ///
  /// In ro, this message translates to:
  /// **'Fixat'**
  String get pinned;

  /// No description provided for @emergencyAlertTitle.
  ///
  /// In ro, this message translates to:
  /// **'ALERTĂ DE URGENȚĂ'**
  String get emergencyAlertTitle;

  /// No description provided for @sendEmergencyAlert.
  ///
  /// In ro, this message translates to:
  /// **'Trimite Alertă de Urgență'**
  String get sendEmergencyAlert;

  /// No description provided for @emergencyMessageHint.
  ///
  /// In ro, this message translates to:
  /// **'ex. Copil rănit la lac, am nevoie de ajutor'**
  String get emergencyMessageHint;

  /// No description provided for @emergencyMessageConfidentialityWarning.
  ///
  /// In ro, this message translates to:
  /// **'Evită să incluzi numele complet al unui copil sau detalii medicale sensibile — tratează acest mesaj ca fiind vizibil și în afara aplicației.'**
  String get emergencyMessageConfidentialityWarning;

  /// No description provided for @emergencyAlertSent.
  ///
  /// In ro, this message translates to:
  /// **'Alertă de urgență trimisă!'**
  String get emergencyAlertSent;

  /// No description provided for @emergencyHistory.
  ///
  /// In ro, this message translates to:
  /// **'Istoric Alerte'**
  String get emergencyHistory;

  /// No description provided for @noEmergencyAlerts.
  ///
  /// In ro, this message translates to:
  /// **'Nicio alertă de urgență'**
  String get noEmergencyAlerts;

  /// No description provided for @acknowledge.
  ///
  /// In ro, this message translates to:
  /// **'Am confirmat'**
  String get acknowledge;

  /// No description provided for @acknowledged.
  ///
  /// In ro, this message translates to:
  /// **'Confirmat'**
  String get acknowledged;

  /// No description provided for @acknowledgedBy.
  ///
  /// In ro, this message translates to:
  /// **'Confirmat de'**
  String get acknowledgedBy;

  /// No description provided for @emergencyOverlayTitle.
  ///
  /// In ro, this message translates to:
  /// **'URGENȚĂ'**
  String get emergencyOverlayTitle;

  /// No description provided for @sentBy.
  ///
  /// In ro, this message translates to:
  /// **'Trimis de'**
  String get sentBy;

  /// No description provided for @enterEmergencyMessage.
  ///
  /// In ro, this message translates to:
  /// **'Introdu mesajul de urgență'**
  String get enterEmergencyMessage;

  /// No description provided for @emergencyConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă trimiterea'**
  String get emergencyConfirm;

  /// No description provided for @emergencyConfirmMessage.
  ///
  /// In ro, this message translates to:
  /// **'Aceasta va trimite o alertă de urgență tuturor ghizilor. Continui?'**
  String get emergencyConfirmMessage;

  /// No description provided for @addLocation.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă Locație'**
  String get addLocation;

  /// No description provided for @editLocation.
  ///
  /// In ro, this message translates to:
  /// **'Editează Locație'**
  String get editLocation;

  /// No description provided for @deleteLocation.
  ///
  /// In ro, this message translates to:
  /// **'Șterge Locație'**
  String get deleteLocation;

  /// No description provided for @deleteLocationConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Ești sigur că vrei să ștergi această locație?'**
  String get deleteLocationConfirm;

  /// No description provided for @locationName.
  ///
  /// In ro, this message translates to:
  /// **'Nume Locație'**
  String get locationName;

  /// No description provided for @locationDescription.
  ///
  /// In ro, this message translates to:
  /// **'Descriere'**
  String get locationDescription;

  /// No description provided for @locationCategory.
  ///
  /// In ro, this message translates to:
  /// **'Categorie'**
  String get locationCategory;

  /// No description provided for @locationPhoto.
  ///
  /// In ro, this message translates to:
  /// **'Fotografie'**
  String get locationPhoto;

  /// No description provided for @locationFacts.
  ///
  /// In ro, this message translates to:
  /// **'Informații'**
  String get locationFacts;

  /// No description provided for @locationFunFact.
  ///
  /// In ro, this message translates to:
  /// **'Fapt Amuzant'**
  String get locationFunFact;

  /// No description provided for @quizQuestion.
  ///
  /// In ro, this message translates to:
  /// **'Întrebare Quiz'**
  String get quizQuestion;

  /// No description provided for @quizAnswer.
  ///
  /// In ro, this message translates to:
  /// **'Răspuns Quiz'**
  String get quizAnswer;

  /// No description provided for @categoryAll.
  ///
  /// In ro, this message translates to:
  /// **'Toate'**
  String get categoryAll;

  /// No description provided for @categoryNature.
  ///
  /// In ro, this message translates to:
  /// **'Natură'**
  String get categoryNature;

  /// No description provided for @categoryHistorical.
  ///
  /// In ro, this message translates to:
  /// **'Istoric'**
  String get categoryHistorical;

  /// No description provided for @categoryActivity.
  ///
  /// In ro, this message translates to:
  /// **'Activitate'**
  String get categoryActivity;

  /// No description provided for @categoryViewpoint.
  ///
  /// In ro, this message translates to:
  /// **'Punct Panoramic'**
  String get categoryViewpoint;

  /// No description provided for @addFact.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă'**
  String get addFact;

  /// No description provided for @removeFact.
  ///
  /// In ro, this message translates to:
  /// **'Șterge'**
  String get removeFact;

  /// No description provided for @takePhoto.
  ///
  /// In ro, this message translates to:
  /// **'Fă o Fotografie'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In ro, this message translates to:
  /// **'Alege din Galerie'**
  String get chooseFromGallery;

  /// No description provided for @saveLocation.
  ///
  /// In ro, this message translates to:
  /// **'Salvează Locația'**
  String get saveLocation;

  /// No description provided for @locationCreated.
  ///
  /// In ro, this message translates to:
  /// **'Locație creată cu succes!'**
  String get locationCreated;

  /// No description provided for @locationUpdated.
  ///
  /// In ro, this message translates to:
  /// **'Locație actualizată cu succes!'**
  String get locationUpdated;

  /// No description provided for @locationDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Locație ștearsă!'**
  String get locationDeleted;

  /// No description provided for @noLocationsYet.
  ///
  /// In ro, this message translates to:
  /// **'Nicio locație adăugată încă'**
  String get noLocationsYet;

  /// No description provided for @uploadingPhoto.
  ///
  /// In ro, this message translates to:
  /// **'Se încarcă fotografia...'**
  String get uploadingPhoto;

  /// No description provided for @savingLocation.
  ///
  /// In ro, this message translates to:
  /// **'Se salvează locația...'**
  String get savingLocation;

  /// No description provided for @gpsUnavailable.
  ///
  /// In ro, this message translates to:
  /// **'GPS indisponibil'**
  String get gpsUnavailable;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In ro, this message translates to:
  /// **'Permisiunea de localizare a fost refuzată'**
  String get locationPermissionDenied;

  /// No description provided for @facts.
  ///
  /// In ro, this message translates to:
  /// **'Informații'**
  String get facts;

  /// No description provided for @funFact.
  ///
  /// In ro, this message translates to:
  /// **'Fapt Amuzant'**
  String get funFact;

  /// No description provided for @quiz.
  ///
  /// In ro, this message translates to:
  /// **'Quiz'**
  String get quiz;

  /// No description provided for @revealAnswer.
  ///
  /// In ro, this message translates to:
  /// **'Arată Răspunsul'**
  String get revealAnswer;

  /// No description provided for @myLocation.
  ///
  /// In ro, this message translates to:
  /// **'Locația Mea'**
  String get myLocation;

  /// No description provided for @enterLocationName.
  ///
  /// In ro, this message translates to:
  /// **'Introdu numele locației'**
  String get enterLocationName;

  /// No description provided for @enterDescription.
  ///
  /// In ro, this message translates to:
  /// **'Introdu o descriere'**
  String get enterDescription;

  /// No description provided for @enterFunFact.
  ///
  /// In ro, this message translates to:
  /// **'Introdu un fapt amuzant'**
  String get enterFunFact;

  /// No description provided for @photoRequired.
  ///
  /// In ro, this message translates to:
  /// **'Te rugăm adaugă o fotografie'**
  String get photoRequired;

  /// No description provided for @mapLocations.
  ///
  /// In ro, this message translates to:
  /// **'Locații pe Hartă'**
  String get mapLocations;

  /// No description provided for @mapLocationsSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Gestionează locațiile și baza de cunoștințe'**
  String get mapLocationsSubtitle;

  /// No description provided for @knowledgeBase.
  ///
  /// In ro, this message translates to:
  /// **'Baza de Cunoștințe'**
  String get knowledgeBase;

  /// No description provided for @knowledgeBaseDescription.
  ///
  /// In ro, this message translates to:
  /// **'Descriere'**
  String get knowledgeBaseDescription;

  /// No description provided for @knowledgeBaseFacts.
  ///
  /// In ro, this message translates to:
  /// **'Informații'**
  String get knowledgeBaseFacts;

  /// No description provided for @knowledgeBaseFunFact.
  ///
  /// In ro, this message translates to:
  /// **'Fapt Amuzant'**
  String get knowledgeBaseFunFact;

  /// No description provided for @knowledgeBaseDescriptionHint.
  ///
  /// In ro, this message translates to:
  /// **'Scrie o descriere generală a locului...'**
  String get knowledgeBaseDescriptionHint;

  /// No description provided for @knowledgeBaseFactsHint.
  ///
  /// In ro, this message translates to:
  /// **'Scrie informații interesante despre acest loc...'**
  String get knowledgeBaseFactsHint;

  /// No description provided for @knowledgeBaseFunFactHint.
  ///
  /// In ro, this message translates to:
  /// **'Scrie un fapt amuzant sau surprinzător...'**
  String get knowledgeBaseFunFactHint;

  /// No description provided for @knowledgeBaseSaved.
  ///
  /// In ro, this message translates to:
  /// **'Baza de cunoștințe salvată!'**
  String get knowledgeBaseSaved;

  /// No description provided for @noMasterLocations.
  ///
  /// In ro, this message translates to:
  /// **'Nicio locație creată încă'**
  String get noMasterLocations;

  /// No description provided for @addToSession.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă la Sesiune'**
  String get addToSession;

  /// No description provided for @selectLocation.
  ///
  /// In ro, this message translates to:
  /// **'Selectează Locația'**
  String get selectLocation;

  /// No description provided for @groupPhoto.
  ///
  /// In ro, this message translates to:
  /// **'Fotografie de Grup'**
  String get groupPhoto;

  /// No description provided for @groupPhotoHint.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă o fotografie cu grupul la această locație'**
  String get groupPhotoHint;

  /// No description provided for @locationAddedToSession.
  ///
  /// In ro, this message translates to:
  /// **'Locație adăugată la sesiune!'**
  String get locationAddedToSession;

  /// No description provided for @locationAlreadyInSession.
  ///
  /// In ro, this message translates to:
  /// **'Această locație este deja adăugată la sesiune'**
  String get locationAlreadyInSession;

  /// No description provided for @removeFromSession.
  ///
  /// In ro, this message translates to:
  /// **'Șterge din Sesiune'**
  String get removeFromSession;

  /// No description provided for @removeFromSessionConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Ești sigur că vrei să ștergi această locație din sesiune?'**
  String get removeFromSessionConfirm;

  /// No description provided for @locationRemovedFromSession.
  ///
  /// In ro, this message translates to:
  /// **'Locație ștearsă din sesiune!'**
  String get locationRemovedFromSession;

  /// No description provided for @activityName.
  ///
  /// In ro, this message translates to:
  /// **'Numele Activității'**
  String get activityName;

  /// No description provided for @activityDescription.
  ///
  /// In ro, this message translates to:
  /// **'Descriere (opțional)'**
  String get activityDescription;

  /// No description provided for @selectDate.
  ///
  /// In ro, this message translates to:
  /// **'Selectează Data'**
  String get selectDate;

  /// No description provided for @startTimeLabel.
  ///
  /// In ro, this message translates to:
  /// **'Ora de început'**
  String get startTimeLabel;

  /// No description provided for @endTimeLabel.
  ///
  /// In ro, this message translates to:
  /// **'Ora de sfârșit'**
  String get endTimeLabel;

  /// No description provided for @newScheduleEntry.
  ///
  /// In ro, this message translates to:
  /// **'Activitate Nouă'**
  String get newScheduleEntry;

  /// No description provided for @editScheduleEntry.
  ///
  /// In ro, this message translates to:
  /// **'Editează Activitate'**
  String get editScheduleEntry;

  /// No description provided for @scheduleEntryCreated.
  ///
  /// In ro, this message translates to:
  /// **'Activitate adăugată!'**
  String get scheduleEntryCreated;

  /// No description provided for @scheduleEntryUpdated.
  ///
  /// In ro, this message translates to:
  /// **'Activitate actualizată!'**
  String get scheduleEntryUpdated;

  /// No description provided for @scheduleEntryDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Activitate ștearsă!'**
  String get scheduleEntryDeleted;

  /// No description provided for @noScheduleEntries.
  ///
  /// In ro, this message translates to:
  /// **'Nicio activitate programată încă'**
  String get noScheduleEntries;

  /// No description provided for @selectDateRequired.
  ///
  /// In ro, this message translates to:
  /// **'Selectează o dată'**
  String get selectDateRequired;

  /// No description provided for @selectTimeRequired.
  ///
  /// In ro, this message translates to:
  /// **'Selectează ora'**
  String get selectTimeRequired;

  /// No description provided for @program.
  ///
  /// In ro, this message translates to:
  /// **'Program'**
  String get program;

  /// No description provided for @whatsYourName.
  ///
  /// In ro, this message translates to:
  /// **'Cum te cheamă?'**
  String get whatsYourName;

  /// No description provided for @enterYourName.
  ///
  /// In ro, this message translates to:
  /// **'Introdu numele tău'**
  String get enterYourName;

  /// No description provided for @nameHint.
  ///
  /// In ro, this message translates to:
  /// **'ex. Andrei'**
  String get nameHint;

  /// No description provided for @continueButton.
  ///
  /// In ro, this message translates to:
  /// **'Continuă'**
  String get continueButton;

  /// No description provided for @nameRequired.
  ///
  /// In ro, this message translates to:
  /// **'Te rugăm introdu numele tău'**
  String get nameRequired;

  /// No description provided for @selected.
  ///
  /// In ro, this message translates to:
  /// **'Selectată'**
  String get selected;

  /// No description provided for @deleteSession.
  ///
  /// In ro, this message translates to:
  /// **'Șterge Sesiunea'**
  String get deleteSession;

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Ești sigur că vrei să ștergi această sesiune? Toate datele vor fi pierdute.'**
  String get deleteSessionConfirm;

  /// No description provided for @sessionDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Sesiune ștearsă!'**
  String get sessionDeleted;

  /// No description provided for @startChat.
  ///
  /// In ro, this message translates to:
  /// **'Începe conversația'**
  String get startChat;

  /// No description provided for @loadingGuide.
  ///
  /// In ro, this message translates to:
  /// **'Se încarcă ghidul...'**
  String get loadingGuide;

  /// No description provided for @chatPlaceholder.
  ///
  /// In ro, this message translates to:
  /// **'Întreabă ceva despre acest loc...'**
  String get chatPlaceholder;

  /// No description provided for @newConversation.
  ///
  /// In ro, this message translates to:
  /// **'Conversație nouă'**
  String get newConversation;

  /// No description provided for @confirmPointsMessage.
  ///
  /// In ro, this message translates to:
  /// **'{action} {points} puncte pentru {team}?'**
  String confirmPointsMessage(
    String action,
    int points,
    String preposition,
    String team,
  );

  /// No description provided for @addVerb.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă'**
  String get addVerb;

  /// No description provided for @removeVerb.
  ///
  /// In ro, this message translates to:
  /// **'Scade'**
  String get removeVerb;

  /// No description provided for @prepositionTo.
  ///
  /// In ro, this message translates to:
  /// **''**
  String get prepositionTo;

  /// No description provided for @prepositionFrom.
  ///
  /// In ro, this message translates to:
  /// **''**
  String get prepositionFrom;

  /// No description provided for @teamsCount.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{{count} echipă} other{{count} echipe}}'**
  String teamsCount(int count);

  /// No description provided for @codesCount.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{{count} cod} other{{count} coduri}}'**
  String codesCount(int count);

  /// No description provided for @deleteTeamConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Sigur ștergi echipa {name}?'**
  String deleteTeamConfirm(String name);

  /// No description provided for @reassignKidsPrompt.
  ///
  /// In ro, this message translates to:
  /// **'Mută {count} copii în echipa:'**
  String reassignKidsPrompt(int count);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hu', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'hu':
      return AppL10nHu();
    case 'ro':
      return AppL10nRo();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
