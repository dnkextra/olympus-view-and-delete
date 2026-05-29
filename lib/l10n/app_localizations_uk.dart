// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Менеджер камер Olympus';

  @override
  String get checkingCamera => 'Перевірка камери...';

  @override
  String connectingTo(Object name) {
    return 'Підключення до $name...';
  }

  @override
  String get wifiConnected => 'WiFi підключено, з\'єднання з камерою...';

  @override
  String get wifiFailed => 'Помилка підключення до WiFi';

  @override
  String get cannotConnect =>
      'Не вдалося підключитися до камери.\nСпочатку підключіться до WiFi камери.';

  @override
  String get retrying => 'Повтор...';

  @override
  String get loadingCameraInfo => 'Завантаження інформації про камеру...';

  @override
  String get loadingFileList => 'Завантаження списку файлів...';

  @override
  String get downloadFiles => 'Завантажити файли';

  @override
  String get deleteFiles => 'Видалити файли';

  @override
  String get downloadFirst => 'Спочатку виберіть файли для завантаження';

  @override
  String get deleteFirst => 'Спочатку виберіть файли для видалення';

  @override
  String get download => 'ЗАВАНТАЖИТИ';

  @override
  String get delete => 'ВИДАЛИТИ';

  @override
  String get cancel => 'Скасувати';

  @override
  String get selectFiles => 'Вибрати файли';

  @override
  String get selectAllDelete => 'Вибрати всі та видалити';

  @override
  String get noFilesFound => 'Файли не знайдено';

  @override
  String get clearFilters => 'Скинути фільтри';

  @override
  String get connected => 'Підключено';

  @override
  String get disconnected => 'Відключено';

  @override
  String get loading => 'Завантаження...';

  @override
  String get about => 'Про програму';

  @override
  String get savedCameras => 'Збережені камери';

  @override
  String get selectAll => 'Вибрати всі';

  @override
  String get deselectAll => 'Зняти виділення';

  @override
  String get selectByDates => 'Вибрати всі за датами';

  @override
  String get showRaw => 'Показати RAW-файли';

  @override
  String get hideRaw => 'Сховати RAW-файли';

  @override
  String get info => 'Інфо';

  @override
  String get retryConnection => 'Повторити підключення';

  @override
  String get scanQr => 'Сканувати QR-код';

  @override
  String get connectWifi => 'Підключити WiFi';

  @override
  String get filterByDate => 'Фільтр за датою';

  @override
  String get allDates => 'Всі дати';

  @override
  String get dateRange => 'Діапазон дат';

  @override
  String get from => 'З...';

  @override
  String get to => 'По...';

  @override
  String get applyRange => 'Застосувати діапазон';

  @override
  String get noDatesAvailable => 'Немає доступних дат';

  @override
  String get downloading => 'Завантаження...';

  @override
  String get deletingFiles => 'Видалення файлів...';

  @override
  String get files => 'файлів';
}
