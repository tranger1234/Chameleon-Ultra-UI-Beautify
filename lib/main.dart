import 'dart:io';
import 'package:chameleonultragui/bridge/chameleon.dart';
import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:chameleonultragui/connector/serial_android.dart';
import 'package:chameleonultragui/connector/serial_ble.dart';
import 'package:chameleonultragui/connector/serial_emulator.dart';
import 'package:chameleonultragui/connector/serial_macos.dart';
import 'package:chameleonultragui/gui/page/tools.dart';
import 'package:chameleonultragui/gui/page/plugins.dart';
import 'package:chameleonultragui/helpers/font.dart';
import 'package:chameleonultragui/helpers/general.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_native/liquid_glass_native.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'connector/serial_native.dart';

// Page imports
import 'package:chameleonultragui/gui/page/home.dart';
import 'package:chameleonultragui/gui/page/saved_cards.dart';
import 'package:chameleonultragui/gui/page/settings.dart';
import 'package:chameleonultragui/gui/page/connect.dart';
import 'package:chameleonultragui/gui/page/debug.dart';
import 'package:chameleonultragui/gui/page/slot_manager.dart';
import 'package:chameleonultragui/gui/page/flashing.dart';
import 'package:chameleonultragui/gui/page/read_card.dart';
import 'package:chameleonultragui/gui/page/write_card.dart';
import 'package:chameleonultragui/gui/page/pending_connection.dart';

// Localizations
import 'package:chameleonultragui/generated/i18n/app_localizations.dart';

// Shared Preferences Provider
import 'package:chameleonultragui/sharedprefsprovider.dart';

// Logger
import 'package:logger/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferencesProvider = SharedPreferencesProvider();
  await sharedPreferencesProvider.load();
  runApp(ChameleonGUI(sharedPreferencesProvider));
}

class ChameleonGUI extends StatelessWidget {
  // Root Widget
  final SharedPreferencesProvider _sharedPreferencesProvider;
  const ChameleonGUI(this._sharedPreferencesProvider, {super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _sharedPreferencesProvider),
        ChangeNotifierProvider(
          create: (context) => ChameleonGUIState(_sharedPreferencesProvider),
        ),
      ],
      child: MainPage(sharedPreferencesProvider: _sharedPreferencesProvider),
    );
  }
}

class ChameleonGUIState extends ChangeNotifier {
  final SharedPreferencesProvider sharedPreferencesProvider;
  ChameleonGUIState(this.sharedPreferencesProvider);

  SharedPreferencesProvider? _sharedPreferencesProvider;
  Logger? log; // Logger

  // Android uses AndroidSerial, iOS can only use BLESerial
  // The rest (desktops?) can use NativeSerial
  AbstractSerial? connector;
  ChameleonCommunicator? communicator;

  bool devMode = false;
  double? progress; // DFU

  // Flashing easter egg
  bool easterEgg = false;
  dynamic _suppressedAutoReconnectPort;

  GlobalKey navigationRailKey = GlobalKey();
  Size? navigationRailSize;

  void changesMade() {
    notifyListeners();
  }

  void onConnectorStateChanged() {
    if (connector == null || !connector!.connected) {
      communicator = null;
      progress = null;
    }
    notifyListeners();
  }

  bool isAutoReconnectSuppressed(dynamic devicePort) {
    return _suppressedAutoReconnectPort == devicePort;
  }

  void clearAutoReconnectSuppression([dynamic devicePort]) {
    if (devicePort == null || _suppressedAutoReconnectPort == devicePort) {
      _suppressedAutoReconnectPort = null;
    }
  }

  void syncAutoReconnectSuppression(Iterable<dynamic> visiblePorts) {
    if (_suppressedAutoReconnectPort == null) {
      return;
    }

    for (final port in visiblePorts) {
      if (port == _suppressedAutoReconnectPort) {
        return;
      }
    }

    _suppressedAutoReconnectPort = null;
  }

  Future<void> disconnect({bool manual = false}) async {
    final suppressedPort = manual ? connector?.activeDevicePort : null;
    await connector?.performDisconnect();
    if (manual && suppressedPort != null) {
      _suppressedAutoReconnectPort = suppressedPort;
    }
    communicator = null;
    progress = null;
    notifyListeners();
  }

  void setProgressBar(dynamic value) {
    progress = value;
    notifyListeners();
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.sharedPreferencesProvider});

  final SharedPreferencesProvider sharedPreferencesProvider;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  var selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => updateNavigationRailWidth(context));
  }

  @override
  void reassemble() async {
    // Disconnect on reload
    var appState = Provider.of<ChameleonGUIState>(context, listen: false);
    await appState.disconnect();

    super.reassemble();
  }

  AbstractSerial getConnector(ChameleonGUIState appState) {
    if (appState._sharedPreferencesProvider!.isEmulatedChameleon()) {
      return EmulatorSerial(log: appState.log!);
    }

    if (Platform.isMacOS) {
      return MacOSSerial(log: appState.log!);
    }

    if (Platform.isAndroid) {
      return AndroidSerial(log: appState.log!);
    }

    if (Platform.isIOS) {
      return BLESerial(log: appState.log!);
    }

    return NativeSerial(log: appState.log!);
  }

  Logger getLogger(ChameleonGUIState appState) {
    if (appState._sharedPreferencesProvider!.isDebugLogging() &&
        appState._sharedPreferencesProvider!.isDebugMode()) {
      return Logger(
        output: SharedPreferencesLogger(appState._sharedPreferencesProvider!),
        printer: PrettyPrinter(
          noBoxingByDefault: true,
        ),
        filter: ChameleonLogFilter(),
      );
    } else {
      return Logger();
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ChameleonGUIState>();
    appState._sharedPreferencesProvider = widget.sharedPreferencesProvider;
    appState.log ??= getLogger(appState);
    appState.connector ??= getConnector(appState);
    appState.connector!.connectionStateCallback =
        appState.onConnectorStateChanged;

    if (appState.sharedPreferencesProvider.getSideBarAutoExpansion()) {
      double width = MediaQuery.of(context).size.width;
      if (width >= 600) {
        appState.sharedPreferencesProvider.setSideBarExpanded(true);
      } else {
        appState.sharedPreferencesProvider.setSideBarExpanded(false);
      }
    }

    appState.devMode = appState.sharedPreferencesProvider.isDebugMode();

    Widget page; // Set Page
    if (!appState.connector!.connected &&
        selectedIndex != 0 &&
        selectedIndex != 2 &&
        selectedIndex != 5 &&
        selectedIndex != 6 &&
        selectedIndex != 7 &&
        selectedIndex != 8) {
      // Offline pages remain available without a device.
      selectedIndex = 0;
    }

    switch (selectedIndex) {
      // Sidebar Navigation
      case 0:
        if (appState.connector!.pendingConnection) {
          page = const PendingConnectionPage();
        } else {
          if (appState.connector!.connected) {
            if (appState.connector!.isDFU) {
              page = const FlashingPage();
            } else {
              page = const HomePage();
            }
          } else {
            page = const ConnectPage();
          }
        }
        break;
      case 1:
        page = const SlotManagerPage();
        break;
      case 2:
        page = const SavedCardsPage();
        break;
      case 3:
        page = const ReadCardPage();
        break;
      case 4:
        page = const WriteCardPage();
        break;
      case 5:
        page = const ToolsPage();
        break;
      case 6:
        page = const PluginsPage();
        break;
      case 7:
        page = const SettingsMainPage();
        break;
      case 8:
        page = const DebugPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    try {
      WakelockPlus.toggle(enable: page is FlashingPage);
    } catch (_) {}

    return MaterialApp(
      title: 'Chameleon Ultra GUI', // App Name
      locale: widget.sharedPreferencesProvider.getLocale(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: widget.sharedPreferencesProvider.getThemeColor()),
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: ColorScheme.fromSeed(
                        seedColor:
                            widget.sharedPreferencesProvider.getThemeColor(),
                        brightness: Brightness.light)
                    .surface,
                statusBarBrightness: Brightness.light,
                statusBarIconBrightness: Brightness.dark)),
        // HIG rule 7 (global registration): popup / dropdown layers are a
        // functional layer. On iOS 26 the native LiquidGlassMenu renders a real
        // regular glass panel (blur + 0.60-0.80 tint) on the system side.
        // Material's PopupMenuTheme cannot blur, so - per the "no fake blur"
        // rule - everything landing here is an OPAQUE elevated surface with the
        // same radius, elevation and layout.
        popupMenuTheme: PopupMenuThemeData(
          color: ColorScheme.fromSeed(
            seedColor: widget.sharedPreferencesProvider.getThemeColor(),
            brightness: Brightness.light,
          ).surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
      ).useCustomSystemFont(Brightness.light),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: widget.sharedPreferencesProvider.getThemeColor(),
            brightness: Brightness.dark),
        brightness: Brightness.dark,
        appBarTheme: AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: ColorScheme.fromSeed(
                        seedColor:
                            widget.sharedPreferencesProvider.getThemeColor(),
                        brightness: Brightness.dark)
                    .surface,
                statusBarBrightness: Brightness.dark,
                statusBarIconBrightness: Brightness.light)),
        // Same rule-7 fallback as the light theme: opaque elevated surface,
        // no translucency, no hand-rolled blur.
        popupMenuTheme: PopupMenuThemeData(
          color: ColorScheme.fromSeed(
            seedColor: widget.sharedPreferencesProvider.getThemeColor(),
            brightness: Brightness.dark,
          ).surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
      ).useCustomSystemFont(Brightness.dark),
      themeMode: widget.sharedPreferencesProvider.getTheme(), // Dark Theme
      // Global Liquid Glass defaults: brand tint + concentric 16px radius.
      // iOS 26+ renders real SwiftUI glass; other platforms ignore this and
      // fall back to the standard Material surfaces.
      builder: (context, child) => LiquidGlassTheme(
        data: LiquidGlassThemeData(
          tint: Theme.of(context).colorScheme.primary,
          borderRadius: 16,
          respectAccessibility: true,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: LayoutBuilder(// Build Page
          builder: (context, constraints) {
        return SafeArea(
          left: false,
          right: false,
          top: false,
          bottom: true,
          child: Scaffold(
              body: Row(
                children: [
                  (!appState.connector!.isDFU || !appState.connector!.connected)
                      ? SafeArea(
                          // Functional layer: the navigation column floats over
                          // the content, so it gets regular glass on iOS 26+
                          // (opaque Material surface elsewhere). Destinations
                          // and routing are untouched.
                          child: LiquidGlassContainer(
                            borderRadius: 16,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: NavigationRail(
                            key: appState.navigationRailKey,
                            backgroundColor: Colors.transparent,
                            // Sidebar
                            extended: appState.sharedPreferencesProvider
                                .getSideBarExpanded(),
                            destinations: [
                              // Sidebar Items
                              NavigationRailDestination(
                                icon: const Icon(Icons.home),
                                label: Text(
                                    AppLocalizations.of(context)!.home), // Home
                              ),
                              NavigationRailDestination(
                                disabled: !appState.connector!.connected,
                                icon: const Icon(Icons.widgets),
                                label: Text(
                                    AppLocalizations.of(context)!.slot_manager),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.auto_awesome_motion),
                                label: Text(
                                    AppLocalizations.of(context)!.saved_cards),
                              ),
                              NavigationRailDestination(
                                disabled: !appState.connector!.connected,
                                icon: const Icon(Icons.sensors),
                                label: Text(
                                    AppLocalizations.of(context)!.read_card),
                              ),
                              NavigationRailDestination(
                                disabled: !appState.connector!.connected,
                                icon: const Icon(Icons.system_update_alt),
                                label: Text(
                                    AppLocalizations.of(context)!.write_card),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.handyman),
                                label:
                                    Text(AppLocalizations.of(context)!.tools),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.extension),
                                label: Text(AppLocalizations.of(context)!.plugins),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.settings),
                                label: Text(
                                    AppLocalizations.of(context)!.settings),
                              ),
                              if (appState.devMode)
                                NavigationRailDestination(
                                  icon: const Icon(Icons.bug_report),
                                  label: Text(
                                      '🐞 ${AppLocalizations.of(context)!.debug} 🐞'),
                                ),
                            ],
                            selectedIndex: selectedIndex,
                            onDestinationSelected: (value) {
                              setState(() {
                                selectedIndex = value;
                              });
                            },
                          ),
                            ),
                          ),
                        )
                      : const SizedBox(),
                  Expanded(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: page,
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: const BottomProgressBar()),
        );
      }),
    );
  }
}

class BottomProgressBar extends StatelessWidget {
  const BottomProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ChameleonGUIState>();
    if (!(appState.connector!.connected && appState.connector!.isDFU)) {
      return const SizedBox();
    }

    final Widget bar = ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: LinearProgressIndicator(
        value: appState.progress,
        minHeight: 6,
        backgroundColor: Colors.grey.withValues(alpha: 0.30),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );

    // DFU progress floats above the page content, so on iOS 26+ it is a glass
    // capsule (regular variant). Everywhere else it keeps an opaque elevated
    // surface with the same radius and padding.
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: bar,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: LiquidGlassContainer(
          borderRadius: 100,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: bar,
          ),
        ),
      ),
    );
  }
}
