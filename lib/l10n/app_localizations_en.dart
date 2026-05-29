// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Olympus Camera Manager';

  @override
  String get checkingCamera => 'Checking camera...';

  @override
  String connectingTo(Object name) {
    return 'Connecting to $name...';
  }

  @override
  String get wifiConnected => 'WiFi connected, reaching camera...';

  @override
  String get wifiFailed => 'WiFi connection failed';

  @override
  String get cannotConnect =>
      'Cannot connect to camera.\nConnect to camera WiFi first.';

  @override
  String get retrying => 'Retrying...';

  @override
  String get loadingCameraInfo => 'Loading camera info...';

  @override
  String get loadingFileList => 'Loading file list...';

  @override
  String get downloadFiles => 'Download Files';

  @override
  String get deleteFiles => 'Delete Files';

  @override
  String get downloadFirst => 'Select files to download first';

  @override
  String get deleteFirst => 'Select files to delete first';

  @override
  String get download => 'DOWNLOAD';

  @override
  String get delete => 'DELETE';

  @override
  String get cancel => 'Cancel';

  @override
  String get selectFiles => 'Select Files';

  @override
  String get selectAllDelete => 'Select All & Delete';

  @override
  String get noFilesFound => 'No files found';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get loading => 'Loading...';

  @override
  String get about => 'About';

  @override
  String get savedCameras => 'Saved cameras';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get selectByDates => 'Select all by same dates';

  @override
  String get showRaw => 'Show RAW files';

  @override
  String get hideRaw => 'Hide RAW files';

  @override
  String get info => 'Info';

  @override
  String get retryConnection => 'Retry Connection';

  @override
  String get scanQr => 'Scan QR Code';

  @override
  String get connectWifi => 'Connect WiFi';

  @override
  String get filterByDate => 'Filter by Date';

  @override
  String get allDates => 'All dates';

  @override
  String get dateRange => 'Date Range';

  @override
  String get from => 'From...';

  @override
  String get to => 'To...';

  @override
  String get applyRange => 'Apply Range';

  @override
  String get noDatesAvailable => 'No dates available';

  @override
  String get downloading => 'Downloading...';

  @override
  String get deletingFiles => 'Deleting files...';

  @override
  String get files => 'files';
}
