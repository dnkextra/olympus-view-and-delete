import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('ru'),
    Locale('uk')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Olympus Camera Manager'**
  String get appTitle;

  /// No description provided for @checkingCamera.
  ///
  /// In en, this message translates to:
  /// **'Checking camera...'**
  String get checkingCamera;

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}...'**
  String connectingTo(Object name);

  /// No description provided for @wifiConnected.
  ///
  /// In en, this message translates to:
  /// **'WiFi connected, reaching camera...'**
  String get wifiConnected;

  /// No description provided for @wifiFailed.
  ///
  /// In en, this message translates to:
  /// **'WiFi connection failed'**
  String get wifiFailed;

  /// No description provided for @cannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to camera.\nConnect to camera WiFi first.'**
  String get cannotConnect;

  /// No description provided for @retrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get retrying;

  /// No description provided for @loadingCameraInfo.
  ///
  /// In en, this message translates to:
  /// **'Loading camera info...'**
  String get loadingCameraInfo;

  /// No description provided for @loadingFileList.
  ///
  /// In en, this message translates to:
  /// **'Loading file list...'**
  String get loadingFileList;

  /// No description provided for @downloadFiles.
  ///
  /// In en, this message translates to:
  /// **'Download Files'**
  String get downloadFiles;

  /// No description provided for @deleteFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete Files'**
  String get deleteFiles;

  /// No description provided for @downloadFirst.
  ///
  /// In en, this message translates to:
  /// **'Select files to download first'**
  String get downloadFirst;

  /// No description provided for @deleteFirst.
  ///
  /// In en, this message translates to:
  /// **'Select files to delete first'**
  String get deleteFirst;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get download;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @selectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select Files'**
  String get selectFiles;

  /// No description provided for @selectAllDelete.
  ///
  /// In en, this message translates to:
  /// **'Select All & Delete'**
  String get selectAllDelete;

  /// No description provided for @noFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get noFilesFound;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @savedCameras.
  ///
  /// In en, this message translates to:
  /// **'Saved cameras'**
  String get savedCameras;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @selectByDates.
  ///
  /// In en, this message translates to:
  /// **'Select all by same dates'**
  String get selectByDates;

  /// No description provided for @showRaw.
  ///
  /// In en, this message translates to:
  /// **'Show RAW files'**
  String get showRaw;

  /// No description provided for @hideRaw.
  ///
  /// In en, this message translates to:
  /// **'Hide RAW files'**
  String get hideRaw;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @retryConnection.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnection;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQr;

  /// No description provided for @connectWifi.
  ///
  /// In en, this message translates to:
  /// **'Connect WiFi'**
  String get connectWifi;

  /// No description provided for @filterByDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by Date'**
  String get filterByDate;

  /// No description provided for @allDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get allDates;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From...'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To...'**
  String get to;

  /// No description provided for @applyRange.
  ///
  /// In en, this message translates to:
  /// **'Apply Range'**
  String get applyRange;

  /// No description provided for @noDatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No dates available'**
  String get noDatesAvailable;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @deletingFiles.
  ///
  /// In en, this message translates to:
  /// **'Deleting files...'**
  String get deletingFiles;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get files;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
