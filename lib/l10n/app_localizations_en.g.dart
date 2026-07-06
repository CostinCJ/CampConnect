// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.g.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CampConnect';

  @override
  String get roleSelectionTitle => 'Who are you?';

  @override
  String get imAGuide => 'I\'m a Guide';

  @override
  String get imAKid => 'I\'m a Camper';

  @override
  String get guideDescription => 'Manage the camp and activities';

  @override
  String get kidDescription => 'Join the camp with a code';

  @override
  String get guideLogin => 'Guide Login';

  @override
  String get createAccount => 'Create Account';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signUpSubtitle => 'Sign up to manage your camp';

  @override
  String get signInSubtitle => 'Sign in to manage your camp';

  @override
  String get displayName => 'Display name';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get hasAccount => 'Already have an account? Sign in';

  @override
  String get noAccount => 'No account? Create one';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get enterEmailForReset => 'Enter your email to reset.';

  @override
  String get resetEmailSent => 'Password reset email sent.';

  @override
  String get kidLogin => 'Join the Camp';

  @override
  String get readyForAdventure => 'Ready for adventure?';

  @override
  String get enterCampCode => 'Enter the camp code your guide gave you!';

  @override
  String get campCode => 'Camp Code';

  @override
  String get askGuideForCode => 'Ask your guide for the code';

  @override
  String get letsGo => 'Let\'s go!';

  @override
  String get invalidCode => 'Invalid camp code. Check it and try again.';

  @override
  String get hey => 'Hi';

  @override
  String get yourTeam => 'YOUR TEAM';

  @override
  String get quickStats => 'Quick Stats';

  @override
  String get teamPoints => 'Team Points';

  @override
  String get pointsShort => 'points';

  @override
  String get defaultTeamRed => 'Red';

  @override
  String get defaultTeamBlue => 'Blue';

  @override
  String get defaultTeamGreen => 'Green';

  @override
  String get defaultTeamYellow => 'Yellow';

  @override
  String get journalEntries => 'Journal Entries';

  @override
  String get welcome => 'Welcome';

  @override
  String get guideDashboard => 'Guide Dashboard';

  @override
  String get sessionOverview => 'Session Overview';

  @override
  String get activeSession => 'Active Session';

  @override
  String get noActiveSession => 'No Active Camp Session';

  @override
  String get createSessionPrompt => 'Create a camp session to get started.';

  @override
  String get createSession => 'Create Session';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get addPoints => 'Add Points';

  @override
  String get postAnnouncement => 'Post Announcement';

  @override
  String get emergencyAlert => 'Emergency Alert';

  @override
  String get manageCodes => 'Manage Codes';

  @override
  String get teams => 'Teams';

  @override
  String get emergency => 'Emergency';

  @override
  String get emergencyMessage =>
      'Emergency alert functionality will be available soon. In case of a real emergency, contact the camp director immediately.';

  @override
  String get send => 'Send';

  @override
  String get ok => 'OK';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get noUserFound => 'No user found.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get romanian => 'Romanian';

  @override
  String get hungarian => 'Hungarian';

  @override
  String get english => 'English';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkThemeActive => 'Dark theme active';

  @override
  String get lightThemeActive => 'Light theme active';

  @override
  String get logout => 'Log out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountWarning =>
      'This permanently deletes your account. If you own the organisation, all its camps are also deleted.';

  @override
  String get deleteMyData => 'Delete my data';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get byContinuingYouAgreeToPrivacyPolicy =>
      'By continuing, you agree to our Privacy Policy';

  @override
  String get campManagement => 'Camp Management';

  @override
  String get campSessionManagement => 'Camp Session Management';

  @override
  String get campSessionManagementSubtitle => 'Create and manage camp sessions';

  @override
  String get codeManagement => 'Code Management';

  @override
  String get codeManagementSubtitle => 'Generate and manage access codes';

  @override
  String get noActivecamp => 'No Active Camp Session';

  @override
  String get selectCampFirst =>
      'Please select an active camp session in Camp Session Management.';

  @override
  String get noCodesYet => 'No codes generated yet';

  @override
  String get tapToGenerate => 'Tap the button below to generate access codes.';

  @override
  String get generateCodes => 'Generate Codes';

  @override
  String get team => 'Team';

  @override
  String get numberOfCodes => 'Number of Codes';

  @override
  String get generate => 'Generate';

  @override
  String get cancel => 'Cancel';

  @override
  String get used => 'Used';

  @override
  String get available => 'Available';

  @override
  String generatedCodesFor(int count, String team) {
    return '$count codes generated for $team';
  }

  @override
  String get home => 'Home';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get map => 'Map';

  @override
  String get journal => 'Journal';

  @override
  String get news => 'News';

  @override
  String get announcements => 'Announcements';

  @override
  String get leaderboardComingSoon => 'Leaderboard — Coming soon';

  @override
  String get pointsManagement => 'Points Management';

  @override
  String get selectTeam => 'Select Team';

  @override
  String get pointAmount => 'Point Amount';

  @override
  String get positiveNegativeHint =>
      'Positive = add points, Negative = subtract points';

  @override
  String get reason => 'Reason';

  @override
  String get reasonHint => 'e.g. Won the relay race';

  @override
  String get submitPoints => 'Submit Points';

  @override
  String get pointsAdded => 'Points added successfully!';

  @override
  String get pointsHistory => 'Points History';

  @override
  String get noPointsHistory => 'No point changes yet';

  @override
  String get teamRankings => 'Team Rankings';

  @override
  String get pts => 'pts';

  @override
  String get enterPoints => 'Enter the point amount';

  @override
  String get enterReason => 'Enter a reason';

  @override
  String get invalidPointAmount => 'Enter a valid number (other than 0)';

  @override
  String get confirmPoints => 'Confirm Points';

  @override
  String get pointsUpdated => 'Points have been updated!';

  @override
  String get rank => 'Rank';

  @override
  String get yourTeamBadge => 'Your Team';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '$count min ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hr ago',
      one: '$count hr ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count d ago',
      one: '$count d ago',
    );
    return '$_temp0';
  }

  @override
  String get noTeamsYet => 'No teams yet';

  @override
  String get noCampSelected => 'Select a camp session';

  @override
  String get mapComingSoon => 'Map — Coming soon';

  @override
  String get journalComingSoon => 'Journal — Coming soon';

  @override
  String get announcementsComingSoon => 'Announcements — Coming soon';

  @override
  String get emergencyComingSoon => 'Emergency Alerts — Coming soon';

  @override
  String get newEntry => 'New Entry';

  @override
  String get editEntry => 'Edit Entry';

  @override
  String get journalTitle => 'Title';

  @override
  String get journalBody => 'What happened today?';

  @override
  String get journalDate => 'Date';

  @override
  String get journalPhotos => 'Photos';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get removePhoto => 'Remove Photo';

  @override
  String get saveEntry => 'Save';

  @override
  String get deleteEntry => 'Delete Entry';

  @override
  String get deleteEntryConfirm =>
      'Are you sure you want to delete this journal entry?';

  @override
  String get entryCreated => 'Entry created successfully!';

  @override
  String get entryUpdated => 'Entry updated successfully!';

  @override
  String get photoRemoved => 'Photo removed';

  @override
  String get undo => 'Undo';

  @override
  String get entryDeleted => 'Entry deleted!';

  @override
  String get noJournalEntries => 'No journal entries yet';

  @override
  String get startWriting => 'Tap the button below to start writing!';

  @override
  String get enterJournalTitle => 'Enter a title';

  @override
  String get enterJournalBody => 'Write what happened...';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get exportingPdf => 'Generating PDF...';

  @override
  String get pdfExported => 'Journal exported successfully!';

  @override
  String get pdfExportError => 'Export error. Please try again.';

  @override
  String get myCampJournal => 'My Camp Journal';

  @override
  String get todayEntry => 'Today\'s entry';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Enter a valid email address';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get campCodeRequired => 'Camp code is required';

  @override
  String get campCodeInvalid => 'Invalid code format (expected: CAMP-XXXX)';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get invalidInviteCode => 'Invalid invite code';

  @override
  String get joinOrganization => 'Join organization';

  @override
  String get createOrganization => 'Create organization';

  @override
  String get organizationName => 'Organization name';

  @override
  String get organizationCode => 'Organization code';

  @override
  String get organizationInviteCode => 'Organization invite code';

  @override
  String get inviteCodeCopied => 'Invite code copied to clipboard!';

  @override
  String get emailAlreadyInUse => 'This email is already in use';

  @override
  String get wrongCredentials => 'Wrong email or password';

  @override
  String get tooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get networkError => 'Network error. Check your internet connection.';

  @override
  String get codeAlreadyUsed => 'This code has already been used.';

  @override
  String get sessionExpired => 'The camp session has ended.';

  @override
  String get teamRank => 'Team rank';

  @override
  String get campSessions => 'Camp Sessions';

  @override
  String get newSession => 'New Session';

  @override
  String get createCampSession => 'Create Camp Session';

  @override
  String get sessionName => 'Session Name';

  @override
  String get sessionNameHint => 'e.g. Summer Camp 2026';

  @override
  String get selectStartDate => 'Select the start date';

  @override
  String get selectEndDate => 'Select the end date';

  @override
  String get noSessionsYet => 'No camp sessions yet';

  @override
  String get tapToCreate => 'Tap the button below to create the first session.';

  @override
  String get active => 'Active';

  @override
  String get ended => 'Ended';

  @override
  String get inProgress => 'In progress';

  @override
  String get activeSessionSet => 'Active session set: ';

  @override
  String get enterSessionName => 'Enter the session name';

  @override
  String get selectDates => 'Select start and end dates';

  @override
  String get selectAtLeastOneTeam => 'Select at least one team';

  @override
  String get endDateBeforeStart => 'End date cannot be before the start date.';

  @override
  String get teamName => 'Team name';

  @override
  String get addTeam => 'Add team';

  @override
  String get editTeam => 'Edit team';

  @override
  String get deleteTeamTitle => 'Delete team';

  @override
  String get cannotDeleteLastTeam => 'Cannot delete the last team.';

  @override
  String get teamsManagementSubtitle => 'Add, rename, or remove teams';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get announcementsFeed => 'News';

  @override
  String get announcementManagement => 'Announcement Management';

  @override
  String get newAnnouncement => 'New Announcement';

  @override
  String get editAnnouncement => 'Edit Announcement';

  @override
  String get announcementTitle => 'Title';

  @override
  String get announcementBody => 'Body';

  @override
  String get announcementType => 'Type';

  @override
  String get typeAnnouncement => 'Announcement';

  @override
  String get typeSchedule => 'Schedule';

  @override
  String get pinnedAnnouncement => 'Pinned';

  @override
  String get deleteAnnouncement => 'Delete Announcement';

  @override
  String get deleteAnnouncementConfirm =>
      'Are you sure you want to delete this announcement?';

  @override
  String get delete => 'Delete';

  @override
  String get announcementCreated => 'Announcement created successfully!';

  @override
  String get announcementUpdated => 'Announcement updated successfully!';

  @override
  String get announcementDeleted => 'Announcement deleted!';

  @override
  String get noAnnouncements => 'No announcements';

  @override
  String get noAnnouncementsYet => 'No announcements yet. Check back later!';

  @override
  String get enterTitle => 'Enter the title';

  @override
  String get enterBody => 'Enter the content';

  @override
  String get postedBy => 'Posted by';

  @override
  String get schedule => 'Schedule';

  @override
  String get scheduleView => 'Schedule View';

  @override
  String get allAnnouncements => 'All Announcements';

  @override
  String get pinned => 'Pinned';

  @override
  String get emergencyAlertTitle => 'EMERGENCY ALERT';

  @override
  String get sendEmergencyAlert => 'Send Emergency Alert';

  @override
  String get emergencyMessageHint =>
      'e.g. Child injured at the lake, need help';

  @override
  String get emergencyMessageConfidentialityWarning =>
      'Avoid including a child\'s full name or sensitive medical details — treat this message as visible outside the app.';

  @override
  String get emergencyAlertSent => 'Emergency alert sent!';

  @override
  String get emergencyHistory => 'Alert History';

  @override
  String get noEmergencyAlerts => 'No emergency alerts';

  @override
  String get acknowledge => 'I acknowledge';

  @override
  String get acknowledged => 'Acknowledged';

  @override
  String get acknowledgedBy => 'Acknowledged by';

  @override
  String get emergencyOverlayTitle => 'EMERGENCY';

  @override
  String get sentBy => 'Sent by';

  @override
  String get enterEmergencyMessage => 'Enter the emergency message';

  @override
  String get emergencyConfirm => 'Confirm send';

  @override
  String get emergencyConfirmMessage =>
      'This will send an emergency alert to all guides. Continue?';

  @override
  String get addLocation => 'Add Location';

  @override
  String get editLocation => 'Edit Location';

  @override
  String get deleteLocation => 'Delete Location';

  @override
  String get deleteLocationConfirm =>
      'Are you sure you want to delete this location?';

  @override
  String get locationName => 'Location Name';

  @override
  String get locationDescription => 'Description';

  @override
  String get locationCategory => 'Category';

  @override
  String get locationPhoto => 'Photo';

  @override
  String get locationFacts => 'Facts';

  @override
  String get locationFunFact => 'Fun Fact';

  @override
  String get quizQuestion => 'Quiz Question';

  @override
  String get quizAnswer => 'Quiz Answer';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryHistorical => 'Historical';

  @override
  String get categoryActivity => 'Activity';

  @override
  String get categoryViewpoint => 'Viewpoint';

  @override
  String get addFact => 'Add';

  @override
  String get removeFact => 'Remove';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get saveLocation => 'Save Location';

  @override
  String get locationCreated => 'Location created successfully!';

  @override
  String get locationUpdated => 'Location updated successfully!';

  @override
  String get locationDeleted => 'Location deleted!';

  @override
  String get noLocationsYet => 'No locations added yet';

  @override
  String get uploadingPhoto => 'Uploading photo...';

  @override
  String get savingLocation => 'Saving location...';

  @override
  String get gpsUnavailable => 'GPS unavailable';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get facts => 'Facts';

  @override
  String get funFact => 'Fun Fact';

  @override
  String get quiz => 'Quiz';

  @override
  String get revealAnswer => 'Reveal Answer';

  @override
  String get myLocation => 'My Location';

  @override
  String get enterLocationName => 'Enter the location name';

  @override
  String get enterDescription => 'Enter a description';

  @override
  String get enterFunFact => 'Enter a fun fact';

  @override
  String get photoRequired => 'Please add a photo';

  @override
  String get mapLocations => 'Map Locations';

  @override
  String get mapLocationsSubtitle => 'Manage locations and knowledge base';

  @override
  String get knowledgeBase => 'Knowledge Base';

  @override
  String get knowledgeBaseDescription => 'Description';

  @override
  String get knowledgeBaseFacts => 'Facts';

  @override
  String get knowledgeBaseFunFact => 'Fun Fact';

  @override
  String get knowledgeBaseDescriptionHint =>
      'Write a general description of the place...';

  @override
  String get knowledgeBaseFactsHint =>
      'Write interesting facts about this place...';

  @override
  String get knowledgeBaseFunFactHint => 'Write a fun or surprising fact...';

  @override
  String get knowledgeBaseSaved => 'Knowledge base saved!';

  @override
  String get noMasterLocations => 'No locations created yet';

  @override
  String get addToSession => 'Add to Session';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get groupPhoto => 'Group Photo';

  @override
  String get groupPhotoHint => 'Add a group photo at this location';

  @override
  String get locationAddedToSession => 'Location added to session!';

  @override
  String get locationAlreadyInSession =>
      'This location is already in the session';

  @override
  String get removeFromSession => 'Remove from Session';

  @override
  String get removeFromSessionConfirm =>
      'Are you sure you want to remove this location from the session?';

  @override
  String get locationRemovedFromSession => 'Location removed from session!';

  @override
  String get activityName => 'Activity Name';

  @override
  String get activityDescription => 'Description (optional)';

  @override
  String get selectDate => 'Select Date';

  @override
  String get startTimeLabel => 'Start time';

  @override
  String get endTimeLabel => 'End time';

  @override
  String get newScheduleEntry => 'New Activity';

  @override
  String get editScheduleEntry => 'Edit Activity';

  @override
  String get scheduleEntryCreated => 'Activity added!';

  @override
  String get scheduleEntryUpdated => 'Activity updated!';

  @override
  String get scheduleEntryDeleted => 'Activity deleted!';

  @override
  String get noScheduleEntries => 'No activities scheduled yet';

  @override
  String get selectDateRequired => 'Select a date';

  @override
  String get selectTimeRequired => 'Select the time';

  @override
  String get program => 'Program';

  @override
  String get whatsYourName => 'What\'s your name?';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get nameHint => 'e.g. Alex';

  @override
  String get continueButton => 'Continue';

  @override
  String get nameRequired => 'Please enter your name';

  @override
  String get selected => 'Selected';

  @override
  String get deleteSession => 'Delete Session';

  @override
  String get deleteSessionConfirm =>
      'Are you sure you want to delete this session? All data will be lost.';

  @override
  String get sessionDeleted => 'Session deleted!';

  @override
  String get startChat => 'Start chat';

  @override
  String get loadingGuide => 'Loading the guide...';

  @override
  String get chatPlaceholder => 'Ask something about this place...';

  @override
  String get newConversation => 'New conversation';

  @override
  String confirmPointsMessage(
    String action,
    int points,
    String preposition,
    String team,
  ) {
    return '$action $points points $preposition $team?';
  }

  @override
  String get addVerb => 'Add';

  @override
  String get removeVerb => 'Remove';

  @override
  String get prepositionTo => 'to';

  @override
  String get prepositionFrom => 'from';

  @override
  String teamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teams',
      one: '$count team',
    );
    return '$_temp0';
  }

  @override
  String codesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count codes',
      one: '$count code',
    );
    return '$_temp0';
  }

  @override
  String deleteTeamConfirm(String name) {
    return 'Delete team $name?';
  }

  @override
  String reassignKidsPrompt(int count) {
    return 'Reassign $count kids to:';
  }
}
