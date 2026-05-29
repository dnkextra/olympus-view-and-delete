// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Менеджер камер Olympus';

  @override
  String get checkingCamera => 'Проверка камеры...';

  @override
  String connectingTo(Object name) {
    return 'Подключение к $name...';
  }

  @override
  String get wifiConnected => 'WiFi подключен, соединение с камерой...';

  @override
  String get wifiFailed => 'Ошибка подключения к WiFi';

  @override
  String get cannotConnect =>
      'Не удалось подключиться к камере.\nСначала подключитесь к WiFi камеры.';

  @override
  String get retrying => 'Повтор...';

  @override
  String get loadingCameraInfo => 'Загрузка информации о камере...';

  @override
  String get loadingFileList => 'Загрузка списка файлов...';

  @override
  String get downloadFiles => 'Скачать файлы';

  @override
  String get deleteFiles => 'Удалить файлы';

  @override
  String get downloadFirst => 'Сначала выберите файлы для скачивания';

  @override
  String get deleteFirst => 'Сначала выберите файлы для удаления';

  @override
  String get download => 'СКАЧАТЬ';

  @override
  String get delete => 'УДАЛИТЬ';

  @override
  String get cancel => 'Отмена';

  @override
  String get selectFiles => 'Выбрать файлы';

  @override
  String get selectAllDelete => 'Выбрать все и удалить';

  @override
  String get noFilesFound => 'Файлы не найдены';

  @override
  String get clearFilters => 'Сбросить фильтры';

  @override
  String get connected => 'Подключено';

  @override
  String get disconnected => 'Отключено';

  @override
  String get loading => 'Загрузка...';

  @override
  String get about => 'О программе';

  @override
  String get savedCameras => 'Сохранённые камеры';

  @override
  String get selectAll => 'Выбрать все';

  @override
  String get deselectAll => 'Снять выделение';

  @override
  String get selectByDates => 'Выбрать все по датам';

  @override
  String get showRaw => 'Показать RAW-файлы';

  @override
  String get hideRaw => 'Скрыть RAW-файлы';

  @override
  String get info => 'Инфо';

  @override
  String get retryConnection => 'Повторить подключение';

  @override
  String get scanQr => 'Сканировать QR-код';

  @override
  String get connectWifi => 'Подключить WiFi';

  @override
  String get filterByDate => 'Фильтр по дате';

  @override
  String get allDates => 'Все даты';

  @override
  String get dateRange => 'Диапазон дат';

  @override
  String get from => 'С...';

  @override
  String get to => 'По...';

  @override
  String get applyRange => 'Применить диапазон';

  @override
  String get noDatesAvailable => 'Нет доступных дат';

  @override
  String get downloading => 'Скачивание...';

  @override
  String get deletingFiles => 'Удаление файлов...';

  @override
  String get files => 'файлов';
}
