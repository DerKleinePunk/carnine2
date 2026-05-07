import 'package:flutter/material.dart';

/// Translation keys used by the frontend.
///
/// Adding a visible string starts here: introduce a key, provide values for all
/// supported languages below, then consume it through [AppLocalizations.text].
enum AppTextKey {
  appTitle,
  navHome,
  navMaps,
  navMedia,
  navClimate,
  navControls,
  navSettings,
  navHomeSemantic,
  navMapsSemantic,
  navMediaSemantic,
  navClimateSemantic,
  navControlsSemantic,
  navSettingsSemantic,
  emergency,
  showFrontendLogs,
  frontendLogs,
  noLogEntriesYet,
  close,
  dashboardContentFor,
  grpcStatus,
  statusNotConnected,
  statusConnecting,
  statusConnected,
  statusError,
  testGrpc,
  connecting,
  canDataLine,
  settingsTitle,
  settingsLanguageTitle,
  settingsLanguageSubtitle,
  settingsMockDescription,
  languageGerman,
  languageEnglish,
  languageFrench,
  languageSpanish,
  languageItalian,
  languageChinese,
  languageJapanese,
}

/// App-localized strings for all supported frontend languages.
class AppLocalizations {
  const AppLocalizations(this.locale);

  static const Locale defaultLocale = Locale('de');
  static const Locale fallbackLocale = Locale('en');
  static const List<Locale> supportedLocales = <Locale>[
    defaultLocale,
    fallbackLocale,
    Locale('fr'),
    Locale('es'),
    Locale('it'),
    Locale('zh'),
    Locale('ja'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  final Locale locale;

  static const Map<String, Map<AppTextKey, String>> _values =
      <String, Map<AppTextKey, String>>{
    'de': <AppTextKey, String>{
      AppTextKey.appTitle: 'CarNine',
      AppTextKey.navHome: 'Start',
      AppTextKey.navMaps: 'Karten',
      AppTextKey.navMedia: 'Medien',
      AppTextKey.navClimate: 'Klima',
      AppTextKey.navControls: 'Technik',
      AppTextKey.navSettings: 'Optionen',
      AppTextKey.navHomeSemantic: 'Start-Dashboard',
      AppTextKey.navMapsSemantic: 'Karten',
      AppTextKey.navMediaSemantic: 'Medienwiedergabe',
      AppTextKey.navClimateSemantic: 'Klimasteuerung',
      AppTextKey.navControlsSemantic: 'Licht- und Steuerungsfunktionen',
      AppTextKey.navSettingsSemantic: 'Einstellungen',
      AppTextKey.emergency: 'NOTFALL',
      AppTextKey.showFrontendLogs: 'Frontend-Logs anzeigen',
      AppTextKey.frontendLogs: 'Frontend-Logs',
      AppTextKey.noLogEntriesYet: 'Noch keine Logeinträge',
      AppTextKey.close: 'Schließen',
      AppTextKey.dashboardContentFor: 'Dashboard-Inhalt für {section}',
      AppTextKey.grpcStatus: 'gRPC-Status: {status}',
      AppTextKey.statusNotConnected: 'Nicht verbunden',
      AppTextKey.statusConnecting: 'Verbindung wird aufgebaut...',
      AppTextKey.statusConnected: 'Verbunden - {count} Datenpunkte empfangen',
      AppTextKey.statusError: 'Fehler: {message}',
      AppTextKey.testGrpc: 'gRPC testen',
      AppTextKey.connecting: 'Verbinden',
      AppTextKey.canDataLine: 'Sensor: {sensor}, Wert: {value}, Zeit: {time}',
      AppTextKey.settingsTitle: 'Einstellungen',
      AppTextKey.settingsLanguageTitle: 'Sprache',
      AppTextKey.settingsLanguageSubtitle: 'Anzeigesprache auswählen',
      AppTextKey.settingsMockDescription:
          'Temporärer Einstellungsbereich für globale Frontend-Optionen.',
      AppTextKey.languageGerman: 'Deutsch',
      AppTextKey.languageEnglish: 'English',
      AppTextKey.languageFrench: 'Französisch',
      AppTextKey.languageSpanish: 'Spanisch',
      AppTextKey.languageItalian: 'Italienisch',
      AppTextKey.languageChinese: 'Chinesisch',
      AppTextKey.languageJapanese: 'Japanisch',
    },
    'en': <AppTextKey, String>{
      AppTextKey.appTitle: 'CarNine',
      AppTextKey.navHome: 'Home',
      AppTextKey.navMaps: 'Maps',
      AppTextKey.navMedia: 'Media',
      AppTextKey.navClimate: 'Climate',
      AppTextKey.navControls: 'Controls',
      AppTextKey.navSettings: 'Settings',
      AppTextKey.navHomeSemantic: 'Home dashboard',
      AppTextKey.navMapsSemantic: 'Maps',
      AppTextKey.navMediaSemantic: 'Media player',
      AppTextKey.navClimateSemantic: 'Climate controls',
      AppTextKey.navControlsSemantic: 'Auxiliary controls',
      AppTextKey.navSettingsSemantic: 'Settings',
      AppTextKey.emergency: 'EMERGENCY',
      AppTextKey.showFrontendLogs: 'Show frontend logs',
      AppTextKey.frontendLogs: 'Frontend Logs',
      AppTextKey.noLogEntriesYet: 'No log entries yet',
      AppTextKey.close: 'Close',
      AppTextKey.dashboardContentFor: 'Dashboard content for {section}',
      AppTextKey.grpcStatus: 'gRPC Status: {status}',
      AppTextKey.statusNotConnected: 'Not connected',
      AppTextKey.statusConnecting: 'Connecting...',
      AppTextKey.statusConnected: 'Connected - received {count} data points',
      AppTextKey.statusError: 'Error: {message}',
      AppTextKey.testGrpc: 'Test gRPC',
      AppTextKey.connecting: 'Connecting',
      AppTextKey.canDataLine: 'Sensor: {sensor}, Value: {value}, Time: {time}',
      AppTextKey.settingsTitle: 'Settings',
      AppTextKey.settingsLanguageTitle: 'Language',
      AppTextKey.settingsLanguageSubtitle: 'Choose display language',
      AppTextKey.settingsMockDescription:
          'Temporary settings area for global frontend options.',
      AppTextKey.languageGerman: 'German',
      AppTextKey.languageEnglish: 'English',
      AppTextKey.languageFrench: 'French',
      AppTextKey.languageSpanish: 'Spanish',
      AppTextKey.languageItalian: 'Italian',
      AppTextKey.languageChinese: 'Chinese',
      AppTextKey.languageJapanese: 'Japanese',
    },
    'fr': <AppTextKey, String>{
      AppTextKey.appTitle: 'CarNine',
      AppTextKey.navHome: 'Accueil',
      AppTextKey.navMaps: 'Cartes',
      AppTextKey.navMedia: 'Médias',
      AppTextKey.navClimate: 'Climat',
      AppTextKey.navControls: 'Contrôle',
      AppTextKey.navSettings: 'Réglages',
      AppTextKey.navHomeSemantic: 'Tableau de bord accueil',
      AppTextKey.navMapsSemantic: 'Cartes',
      AppTextKey.navMediaSemantic: 'Lecteur média',
      AppTextKey.navClimateSemantic: 'Commandes de climatisation',
      AppTextKey.navControlsSemantic: 'Commandes auxiliaires et éclairage',
      AppTextKey.navSettingsSemantic: 'Réglages',
      AppTextKey.emergency: 'URGENCE',
      AppTextKey.showFrontendLogs: 'Afficher les journaux frontend',
      AppTextKey.frontendLogs: 'Journaux frontend',
      AppTextKey.noLogEntriesYet: 'Aucune entrée de journal',
      AppTextKey.close: 'Fermer',
      AppTextKey.dashboardContentFor:
          'Contenu du tableau de bord pour {section}',
      AppTextKey.grpcStatus: 'Statut gRPC : {status}',
      AppTextKey.statusNotConnected: 'Non connecté',
      AppTextKey.statusConnecting: 'Connexion en cours...',
      AppTextKey.statusConnected: 'Connecté - {count} points reçus',
      AppTextKey.statusError: 'Erreur : {message}',
      AppTextKey.testGrpc: 'Tester gRPC',
      AppTextKey.connecting: 'Connexion',
      AppTextKey.canDataLine:
          'Capteur : {sensor}, valeur : {value}, heure : {time}',
      AppTextKey.settingsTitle: 'Réglages',
      AppTextKey.settingsLanguageTitle: 'Langue',
      AppTextKey.settingsLanguageSubtitle: 'Choisir la langue d’affichage',
      AppTextKey.settingsMockDescription:
          'Zone de réglages temporaire pour les options globales du frontend.',
      AppTextKey.languageGerman: 'allemand',
      AppTextKey.languageEnglish: 'anglais',
      AppTextKey.languageFrench: 'français',
      AppTextKey.languageSpanish: 'espagnol',
      AppTextKey.languageItalian: 'italien',
      AppTextKey.languageChinese: 'chinois',
      AppTextKey.languageJapanese: 'japonais',
    },
    'es': <AppTextKey, String>{
      AppTextKey.appTitle: 'CarNine',
      AppTextKey.navHome: 'Inicio',
      AppTextKey.navMaps: 'Mapas',
      AppTextKey.navMedia: 'Medios',
      AppTextKey.navClimate: 'Clima',
      AppTextKey.navControls: 'Control',
      AppTextKey.navSettings: 'Ajustes',
      AppTextKey.navHomeSemantic: 'Panel de inicio',
      AppTextKey.navMapsSemantic: 'Mapas',
      AppTextKey.navMediaSemantic: 'Reproductor multimedia',
      AppTextKey.navClimateSemantic: 'Controles de climatización',
      AppTextKey.navControlsSemantic: 'Controles auxiliares e iluminación',
      AppTextKey.navSettingsSemantic: 'Ajustes',
      AppTextKey.emergency: 'EMERGENCIA',
      AppTextKey.showFrontendLogs: 'Mostrar registros del frontend',
      AppTextKey.frontendLogs: 'Registros del frontend',
      AppTextKey.noLogEntriesYet: 'Aún no hay registros',
      AppTextKey.close: 'Cerrar',
      AppTextKey.dashboardContentFor: 'Contenido del panel para {section}',
      AppTextKey.grpcStatus: 'Estado gRPC: {status}',
      AppTextKey.statusNotConnected: 'Sin conexión',
      AppTextKey.statusConnecting: 'Conectando...',
      AppTextKey.statusConnected: 'Conectado - {count} datos recibidos',
      AppTextKey.statusError: 'Error: {message}',
      AppTextKey.testGrpc: 'Probar gRPC',
      AppTextKey.connecting: 'Conectando',
      AppTextKey.canDataLine: 'Sensor: {sensor}, valor: {value}, hora: {time}',
      AppTextKey.settingsTitle: 'Ajustes',
      AppTextKey.settingsLanguageTitle: 'Idioma',
      AppTextKey.settingsLanguageSubtitle:
          'Seleccionar idioma de visualización',
      AppTextKey.settingsMockDescription:
          'Área temporal de ajustes para opciones globales del frontend.',
      AppTextKey.languageGerman: 'alemán',
      AppTextKey.languageEnglish: 'inglés',
      AppTextKey.languageFrench: 'francés',
      AppTextKey.languageSpanish: 'español',
      AppTextKey.languageItalian: 'italiano',
      AppTextKey.languageChinese: 'chino',
      AppTextKey.languageJapanese: 'japonés',
    },
    'it': <AppTextKey, String>{
      AppTextKey.appTitle: 'CarNine',
      AppTextKey.navHome: 'Home',
      AppTextKey.navMaps: 'Mappe',
      AppTextKey.navMedia: 'Media',
      AppTextKey.navClimate: 'Clima',
      AppTextKey.navControls: 'Comandi',
      AppTextKey.navSettings: 'Opzioni',
      AppTextKey.navHomeSemantic: 'Dashboard home',
      AppTextKey.navMapsSemantic: 'Mappe',
      AppTextKey.navMediaSemantic: 'Lettore multimediale',
      AppTextKey.navClimateSemantic: 'Comandi climatizzazione',
      AppTextKey.navControlsSemantic: 'Comandi ausiliari e illuminazione',
      AppTextKey.navSettingsSemantic: 'Opzioni',
      AppTextKey.emergency: 'EMERGENZA',
      AppTextKey.showFrontendLogs: 'Mostra log frontend',
      AppTextKey.frontendLogs: 'Log frontend',
      AppTextKey.noLogEntriesYet: 'Nessuna voce di log',
      AppTextKey.close: 'Chiudi',
      AppTextKey.dashboardContentFor: 'Contenuto dashboard per {section}',
      AppTextKey.grpcStatus: 'Stato gRPC: {status}',
      AppTextKey.statusNotConnected: 'Non connesso',
      AppTextKey.statusConnecting: 'Connessione...',
      AppTextKey.statusConnected: 'Connesso - {count} dati ricevuti',
      AppTextKey.statusError: 'Errore: {message}',
      AppTextKey.testGrpc: 'Test gRPC',
      AppTextKey.connecting: 'Connessione',
      AppTextKey.canDataLine: 'Sensore: {sensor}, valore: {value}, ora: {time}',
      AppTextKey.settingsTitle: 'Opzioni',
      AppTextKey.settingsLanguageTitle: 'Lingua',
      AppTextKey.settingsLanguageSubtitle:
          'Scegli la lingua di visualizzazione',
      AppTextKey.settingsMockDescription:
          'Area temporanea delle opzioni globali del frontend.',
      AppTextKey.languageGerman: 'tedesco',
      AppTextKey.languageEnglish: 'inglese',
      AppTextKey.languageFrench: 'francese',
      AppTextKey.languageSpanish: 'spagnolo',
      AppTextKey.languageItalian: 'italiano',
      AppTextKey.languageChinese: 'cinese',
      AppTextKey.languageJapanese: 'giapponese',
    },
    'zh': <AppTextKey, String>{
      AppTextKey.appTitle: 'CarNine',
      AppTextKey.navHome: '首页',
      AppTextKey.navMaps: '地图',
      AppTextKey.navMedia: '媒体',
      AppTextKey.navClimate: '空调',
      AppTextKey.navControls: '控制',
      AppTextKey.navSettings: '设置',
      AppTextKey.navHomeSemantic: '首页仪表盘',
      AppTextKey.navMapsSemantic: '地图',
      AppTextKey.navMediaSemantic: '媒体播放器',
      AppTextKey.navClimateSemantic: '空调控制',
      AppTextKey.navControlsSemantic: '辅助控制和灯光',
      AppTextKey.navSettingsSemantic: '设置',
      AppTextKey.emergency: '紧急',
      AppTextKey.showFrontendLogs: '显示前端日志',
      AppTextKey.frontendLogs: '前端日志',
      AppTextKey.noLogEntriesYet: '暂无日志条目',
      AppTextKey.close: '关闭',
      AppTextKey.dashboardContentFor: '{section} 仪表盘内容',
      AppTextKey.grpcStatus: 'gRPC 状态：{status}',
      AppTextKey.statusNotConnected: '未连接',
      AppTextKey.statusConnecting: '正在连接...',
      AppTextKey.statusConnected: '已连接 - 已接收 {count} 个数据点',
      AppTextKey.statusError: '错误：{message}',
      AppTextKey.testGrpc: '测试 gRPC',
      AppTextKey.connecting: '连接中',
      AppTextKey.canDataLine: '传感器：{sensor}，数值：{value}，时间：{time}',
      AppTextKey.settingsTitle: '设置',
      AppTextKey.settingsLanguageTitle: '语言',
      AppTextKey.settingsLanguageSubtitle: '选择显示语言',
      AppTextKey.settingsMockDescription: '用于全局前端选项的临时设置区域。',
      AppTextKey.languageGerman: '德语',
      AppTextKey.languageEnglish: '英语',
      AppTextKey.languageFrench: '法语',
      AppTextKey.languageSpanish: '西班牙语',
      AppTextKey.languageItalian: '意大利语',
      AppTextKey.languageChinese: '中文',
      AppTextKey.languageJapanese: '日语',
    },
    'ja': <AppTextKey, String>{
      AppTextKey.appTitle: 'CarNine',
      AppTextKey.navHome: 'ホーム',
      AppTextKey.navMaps: '地図',
      AppTextKey.navMedia: 'メディア',
      AppTextKey.navClimate: '空調',
      AppTextKey.navControls: '制御',
      AppTextKey.navSettings: '設定',
      AppTextKey.navHomeSemantic: 'ホームダッシュボード',
      AppTextKey.navMapsSemantic: '地図',
      AppTextKey.navMediaSemantic: 'メディアプレーヤー',
      AppTextKey.navClimateSemantic: '空調操作',
      AppTextKey.navControlsSemantic: '補助制御と照明',
      AppTextKey.navSettingsSemantic: '設定',
      AppTextKey.emergency: '緊急',
      AppTextKey.showFrontendLogs: 'フロントエンドログを表示',
      AppTextKey.frontendLogs: 'フロントエンドログ',
      AppTextKey.noLogEntriesYet: 'ログはまだありません',
      AppTextKey.close: '閉じる',
      AppTextKey.dashboardContentFor: '{section} のダッシュボード内容',
      AppTextKey.grpcStatus: 'gRPC ステータス: {status}',
      AppTextKey.statusNotConnected: '未接続',
      AppTextKey.statusConnecting: '接続中...',
      AppTextKey.statusConnected: '接続済み - {count} 件のデータを受信',
      AppTextKey.statusError: 'エラー: {message}',
      AppTextKey.testGrpc: 'gRPC をテスト',
      AppTextKey.connecting: '接続中',
      AppTextKey.canDataLine: 'センサー: {sensor}、値: {value}、時刻: {time}',
      AppTextKey.settingsTitle: '設定',
      AppTextKey.settingsLanguageTitle: '言語',
      AppTextKey.settingsLanguageSubtitle: '表示言語を選択',
      AppTextKey.settingsMockDescription: 'フロントエンド全体のオプション用の一時設定エリアです。',
      AppTextKey.languageGerman: 'ドイツ語',
      AppTextKey.languageEnglish: '英語',
      AppTextKey.languageFrench: 'フランス語',
      AppTextKey.languageSpanish: 'スペイン語',
      AppTextKey.languageItalian: 'イタリア語',
      AppTextKey.languageChinese: '中国語',
      AppTextKey.languageJapanese: '日本語',
    },
  };

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (localizations == null) {
      throw StateError('AppLocalizations is not available in this context.');
    }

    return localizations;
  }

  /// Resolves a translated string and falls back to English for missing keys.
  String text(AppTextKey key) {
    final languageValues = _values[locale.languageCode];
    final fallbackValues = _values[fallbackLocale.languageCode];

    return languageValues?[key] ?? fallbackValues?[key] ?? key.name;
  }

  String dashboardContentFor(String section) {
    return text(AppTextKey.dashboardContentFor)
        .replaceFirst('{section}', section);
  }

  String grpcStatus(String status) {
    return text(AppTextKey.grpcStatus).replaceFirst('{status}', status);
  }

  String statusConnected(int count) {
    return text(AppTextKey.statusConnected)
        .replaceFirst('{count}', count.toString());
  }

  String statusError(String message) {
    return text(AppTextKey.statusError).replaceFirst('{message}', message);
  }

  String canDataLine({
    required String sensor,
    required double value,
    required Object timestamp,
  }) {
    return text(AppTextKey.canDataLine)
        .replaceFirst('{sensor}', sensor)
        .replaceFirst('{value}', value.toString())
        .replaceFirst('{time}', timestamp.toString());
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final selectedLocale = isSupported(locale)
        ? Locale(locale.languageCode)
        : AppLocalizations.fallbackLocale;

    return AppLocalizations(selectedLocale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
