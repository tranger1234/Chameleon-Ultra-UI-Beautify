import 'package:chameleonultragui/gui/component/developer_list.dart';
import 'package:chameleonultragui/gui/component/liquid_glass.dart';
import 'package:chameleonultragui/gui/component/error_page.dart';
import 'package:chameleonultragui/gui/component/toggle_buttons.dart';
import 'package:chameleonultragui/gui/menu/dialogs/qr/settings.dart';
import 'package:chameleonultragui/helpers/general.dart';
import 'package:chameleonultragui/helpers/github.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:chameleonultragui/helpers/open_collective.dart';
import 'package:chameleonultragui/main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:chameleonultragui/gui/component/qrcode_viewer.dart';
import 'package:crypto/crypto.dart';
import 'package:chameleonultragui/gui/menu/dialogs/qr/import.dart';
import 'package:chameleonultragui/gui/menu/pages/changelog_view.dart';
import 'package:flutter/services.dart' show rootBundle;

// Localizations
import 'package:chameleonultragui/generated/i18n/app_localizations.dart';

Future<String> loadLicense(String license) async {
  return await rootBundle.loadString('assets/licenses/$license.md');
}

class SettingsMainPage extends StatefulWidget {
  const SettingsMainPage({super.key});

  @override
  SettingsMainPageState createState() => SettingsMainPageState();
}

class SettingsMainPageState extends State<SettingsMainPage> {
  @override
  void initState() {
    super.initState();
  }

  Future<(String, List<Map<String, String>>, PackageInfo)>
      getFutureData() async {
    return (
      await fetchOCnames(),
      await fetchContributors(),
      await PackageInfo.fromPlatform()
    );
  }

  Future<String> fetchOCnames() async {
    final List<String> names = await fetchOpenCollectiveContributors();

    if (names.isEmpty && mounted) {
      return AppLocalizations.of(context)!.failed_to_fetch_oc_contributors;
    }

    String finalNames = "";
    for (String name in names) {
      finalNames += "$name, ";
    }
    return finalNames.substring(0, finalNames.length - 2);
  }

  Future<List<Map<String, String>>> fetchContributors() async {
    return await fetchGitHubContributors();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ChameleonGUIState>();
    var localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Text(localizations.sidebar_expansion,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              ToggleButtonsWrapper(
                  items: [
                    localizations.expand,
                    localizations.auto,
                    localizations.retract
                  ],
                  selectedValue: appState.sharedPreferencesProvider
                      .getSideBarExpandedIndex(),
                  onChange: (int index) async {
                    if (index == 0) {
                      appState.sharedPreferencesProvider
                          .setSideBarExpanded(true);
                      appState.sharedPreferencesProvider
                          .setSideBarAutoExpansion(false);
                    } else if (index == 2) {
                      appState.sharedPreferencesProvider
                          .setSideBarExpanded(false);
                      appState.sharedPreferencesProvider
                          .setSideBarAutoExpansion(false);
                    } else {
                      appState.sharedPreferencesProvider
                          .setSideBarAutoExpansion(true);
                    }
                    appState.sharedPreferencesProvider
                        .setSideBarExpandedIndex(index);
                    appState.changesMade();

                    WidgetsBinding.instance.addPostFrameCallback(
                        (_) => updateNavigationRailWidth(context));
                  }),
              const SizedBox(height: 10),
              Text(
                localizations.theme,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              ToggleButtonsWrapper(
                  items: [
                    localizations.system,
                    localizations.light,
                    localizations.dark
                  ],
                  selectedValue:
                      appState.sharedPreferencesProvider.getTheme().index,
                  onChange: (int index) async {
                    appState.sharedPreferencesProvider
                        .setTheme(ThemeMode.values[index]);
                    appState.changesMade();
                  }),
              const SizedBox(height: 10),
              Text(
                localizations.color_scheme,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              // Dropdown = popup layer -> HIG rule 7: regular glass menu on
              // iOS 26 (native blur + tint), opaque elevated popup elsewhere.
              GlassSelect<int>(
                label: [
                  localizations.def,
                  localizations.purple,
                  localizations.blue,
                  localizations.green,
                  localizations.indigo,
                  localizations.lime,
                  localizations.red,
                  localizations.yellow,
                ][appState.sharedPreferencesProvider.getThemeColorIndex()],
                value: appState.sharedPreferencesProvider.getThemeColorIndex(),
                sfSymbol: 'paintpalette',
                options: [
                  GlassSelectOption(value: 0, label: localizations.def),
                  GlassSelectOption(value: 1, label: localizations.purple),
                  GlassSelectOption(value: 2, label: localizations.blue),
                  GlassSelectOption(value: 3, label: localizations.green),
                  GlassSelectOption(value: 4, label: localizations.indigo),
                  GlassSelectOption(value: 5, label: localizations.lime),
                  GlassSelectOption(value: 6, label: localizations.red),
                  GlassSelectOption(value: 7, label: localizations.yellow),
                ],
                onSelected: (int value) {
                  appState.sharedPreferencesProvider.setThemeColor(value);
                  appState.changesMade();
                },
              ),
              const SizedBox(height: 10),
              Text(
                localizations.language,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: GlassSelect<String>(
                  label: lookupAppLocalizations(
                    appState.sharedPreferencesProvider.getLocale(),
                  ).language_name,
                  value: appState.sharedPreferencesProvider.getLocaleString(),
                  sfSymbol: 'globe',
                  options: AppLocalizations.supportedLocales.map((locale) {
                    final localeLocalizations = lookupAppLocalizations(locale);
                    return GlassSelectOption(
                        value: locale.toLanguageTag(),
                        label: localeLocalizations.language_name);
                  }).toList(),
                  onSelected: (String value) {
                    appState.sharedPreferencesProvider.setLocale(Locale(value));
                    appState.changesMade();
                  },
                ),
              ),
              const SizedBox(height: 10),
              LiquidGlassLabeledSwitch(
                label: localizations.auto_scan_devices,
                value: appState.sharedPreferencesProvider.getAutoScanEnabled(),
                onChanged: (value) async {
                  appState.sharedPreferencesProvider.setAutoScanEnabled(value);
                  appState.changesMade();
                },
              ),
              const SizedBox(height: 10),
              LiquidGlassLabeledSwitch(
                label: localizations.auto_connect_first_device,
                value: appState.sharedPreferencesProvider
                    .getAutoConnectFirstFoundDevice(),
                onChanged: (value) async {
                  appState.sharedPreferencesProvider
                      .setAutoConnectFirstFoundDevice(value);
                  appState.changesMade();
                },
              ),
              const SizedBox(height: 10),
              LiquidGlassLabeledSwitch(
                label: localizations.confirm_deletions,
                value: appState.sharedPreferencesProvider.getConfirmDelete(),
                onChanged: (value) async {
                  appState.sharedPreferencesProvider.setConfirmDelete(value);
                  appState.changesMade();
                },
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                // Functional page action -> capsule glass on iOS 26+.
                child: GlassAction(
                    leadingSymbol: 'square.and.arrow.up',
                    label: AppLocalizations.of(context)!.export_settings,
                    onPressed: () => showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text(AppLocalizations.of(context)!
                                .choose_export_method),
                            content: Text(AppLocalizations.of(context)!
                                .choose_export_method_description),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(localizations.cancel),
                              ),
                              TextButton(
                                onPressed: () async {
                                  String string = appState
                                      .sharedPreferencesProvider
                                      .dumpSettingsToJson();

                                  Map<String, int> settings = await showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return const QRCodeSettings();
                                          }) ??
                                      {};

                                  if (settings.isEmpty) {
                                    return;
                                  }

                                  List<String> qrChunks =
                                      splitStringIntoQrChunks(string,
                                          settings["splitSize"]!); //2048

                                  // Generate Header Info
                                  Map<String, dynamic> headerData = {
                                    "Info": "Chameleon Ultra GUI Settings",
                                    "chunks": qrChunks.length,
                                    "sha256": sha256
                                        .convert(
                                            const Utf8Encoder().convert(string))
                                        .toString(),
                                  };
                                  qrChunks.insert(0, jsonEncode(headerData));

                                  if (context.mounted) {
                                    await showDialog(
                                      context: context,
                                      builder: (BuildContext context) =>
                                          QrCodeViewer(
                                              qrChunks: qrChunks,
                                              errorCorrection:
                                                  settings["errorCorrection"]!),
                                    );
                                  }

                                  appState.changesMade();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Text(localizations.qr_code),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await FilePicker.saveFile(
                                    dialogTitle:
                                        '${localizations.output_file}:',
                                    fileName: 'ChameleonUltraGUISettings.json',
                                    bytes: const Utf8Encoder().convert(appState
                                        .sharedPreferencesProvider
                                        .dumpSettingsToJson()),
                                  );
                                },
                                child: Text(
                                    AppLocalizations.of(context)!.json_file),
                              ),
                            ],
                          ),
                        ),
                    ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: GlassAction(
                  leadingSymbol: 'square.and.arrow.down',
                  label: AppLocalizations.of(context)!.import_settings,
                  onPressed: () => showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title:
                          Text(AppLocalizations.of(context)!.import_settings),
                      content: Text(AppLocalizations.of(context)!
                          .import_settings_description),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(localizations.cancel),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (!(Platform.isAndroid || Platform.isIOS)) {
                              await showDialog(
                                context: context,
                                builder: (BuildContext context) => AlertDialog(
                                  title:
                                      Text(AppLocalizations.of(context)!.error),
                                  content: Text(AppLocalizations.of(context)!
                                      .qr_code_import_not_supported_description),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(localizations.ok),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            String? jsonData = await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return const QrCodeImport();
                                });

                            if (jsonData == null) {
                              return;
                            }
                            appState.sharedPreferencesProvider
                                .restoreSettingsFromJson(jsonData);

                            appState.changesMade();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: Text(localizations.qr_code),
                        ),
                        TextButton(
                          onPressed: () async {
                            PlatformFile? result = await FilePicker.pickFile();
                            if (result != null) {
                              File file = File(result.path!);
                              var contents = await file.readAsBytes();
                              var string =
                                  const Utf8Decoder().convert(contents);
                              appState.sharedPreferencesProvider
                                  .restoreSettingsFromJson(string);
                              appState.changesMade();
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.json_file),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GlassAction(
                leadingSymbol: 'info.circle',
                label: localizations.about,
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: Text(localizations.about),
                    content: Center(
                      child: FutureBuilder(
                        future: getFutureData(),
                        builder:
                            (BuildContext context, AsyncSnapshot snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            appState.connector!.performDisconnect();
                            return ErrorPage(
                                errorMessage: snapshot.error.toString());
                          } else {
                            final (names, contributors, packageInfo) =
                                snapshot.data;
                            return SingleChildScrollView(
                                child: Column(
                              children: [
                                const Text('Chameleon Ultra GUI',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(localizations.about_text),
                                const SizedBox(height: 10),
                                Text('${localizations.version}:'),
                                Text(
                                    '${packageInfo.version} (Build ${packageInfo.buildNumber})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Text('${localizations.developed_by}:'),
                                const SizedBox(height: 10),
                                DeveloperList(avatars: developers),
                                const SizedBox(height: 10),
                                Text('${localizations.license}:'),
                                const Text('GNU General Public License v3.0',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                GestureDetector(
                                    onTap: () async {
                                      await launchUrl(Uri.parse(
                                          'https://github.com/GameTec-live/ChameleonUltraGUI'));
                                    },
                                    child: const Text(
                                        'https://github.com/GameTec-live/ChameleonUltraGUI')),
                                const SizedBox(height: 30),
                                GestureDetector(
                                    onTap: () async {
                                      await launchUrl(Uri.parse(
                                          'https://opencollective.com/chameleon-ultra-gui'));
                                    },
                                    child:
                                        Text(localizations.thanks_for_support)),
                                const SizedBox(height: 10),
                                Text(names,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Text('${localizations.code_contributors}:'),
                                const SizedBox(height: 10),
                                DeveloperList(avatars: contributors),
                                const SizedBox(height: 10),
                                Text(localizations.trademarks_mifare),
                                const SizedBox(height: 10),
                                Text(localizations.trademarks_em),
                                const SizedBox(height: 10),
                                Text(localizations.trademarks_hid),
                              ],
                            ));
                          }
                        },
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(localizations.ok),
                      ),
                    ],
                  ),
                ),
                
              ),
              const SizedBox(height: 10),
              GlassAction(
                leadingSymbol: 'doc.plaintext',
                label: localizations.licenses,
                onPressed: () async {
                  Map<String, String> licenses = {
                    'BSD-3-Clause': await loadLicense('BSD-3-Clause'),
                    'GPL3': await loadLicense('GPL3'),
                    'LGPL3': await loadLicense('LGPL3'),
                    'MIT': await loadLicense('MIT')
                  };

                  // font.dart
                  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(
                        LicenseEntryWithLineBreaks(
                          <String>['chinese_font_library'],
                          licenses['BSD-3-Clause']!,
                        ),
                      ));

                  // ported hardnested to Windows + MSVC, separation from proxmark3 code
                  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(
                        LicenseEntryWithLineBreaks(
                          <String>['FlipperNestedRecovery'],
                          licenses['LGPL3']!,
                        ),
                      ));

                  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(
                        LicenseEntryWithLineBreaks(
                          <String>['proxmark3'],
                          licenses['GPL3']!,
                        ),
                      ));

                  // hardnested tables uncompressor
                  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(
                        LicenseEntryWithLineBreaks(
                          <String>['minlzma'],
                          licenses['MIT']!,
                        ),
                      ));

                  if (context.mounted) {
                    showLicensePage(context: context);
                  }
                },
                
              ),
              const SizedBox(height: 10),
              GlassAction(
                leadingSymbol: 'clock.arrow.circlepath',
                label: localizations.changelog,
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => const ChangelogView(),
                ),
                
              ),
              const SizedBox(height: 10),
              GlassAction(
                leadingSymbol: 'globe',
                label: localizations.help_translate,
                onPressed: () async {
                  await launchUrl(Uri.parse(
                      'https://crowdin.com/project/chameleonultragui'));
                },
                
              ),
              const SizedBox(height: 10),
              GlassAction(
                leadingSymbol: 'cpu',
                label:
                    "${appState.sharedPreferencesProvider.isEmulatedChameleon() ? localizations.deactivate : localizations.activate} ${localizations.emulate_device.toLowerCase()}",
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: Text(localizations.emulate_device),
                    content: Text(localizations.emulate_device_confirmation(
                        appState.sharedPreferencesProvider.isEmulatedChameleon()
                            ? localizations.deactivate.toLowerCase()
                            : localizations.activate.toLowerCase())),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(localizations.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          appState.sharedPreferencesProvider
                              .setEmulatedChameleon(!appState
                                  .sharedPreferencesProvider
                                  .isEmulatedChameleon());
                          appState.connector = null;
                          appState.changesMade();
                          Navigator.pop(context);
                        },
                        child: Text(localizations.ok),
                      ),
                    ],
                  ),
                ),
                
              ),
              const SizedBox(height: 10),
              GlassAction(
                leadingSymbol: 'ant.fill',
                label:
                    "${appState.sharedPreferencesProvider.isDebugMode() ? localizations.deactivate : localizations.activate} ${localizations.debug_mode.toLowerCase()}",
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: Text(localizations.debug_mode),
                    content: Text(localizations.debug_mode_confirmation(
                        appState.sharedPreferencesProvider.isDebugMode()
                            ? localizations.deactivate.toLowerCase()
                            : localizations.activate.toLowerCase())),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(localizations.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          appState.sharedPreferencesProvider.setDebugMode(
                              !appState.sharedPreferencesProvider
                                  .isDebugMode());
                          appState.changesMade();
                          Navigator.pop(context);
                        },
                        child: Text(localizations.ok),
                      ),
                    ],
                  ),
                ),
                
              )
            ],
          ),
        ),
      ),
    );
  }
}
