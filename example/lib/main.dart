import 'package:flutter/material.dart';

import 'playground/location.dart';
import 'playground/router.dart';
import 'playground/store.dart';
import 'playground/url_strategy_stub.dart'
    if (dart.library.js_interop) 'playground/url_strategy_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  runApp(const TreemapExampleApp());
}

class TreemapExampleApp extends StatefulWidget {
  const TreemapExampleApp({
    super.key,
    this.store,
    this.initialUri,
    this.routeProvider,
  });
  final PlaygroundStore? store;
  final Uri? initialUri;
  final RouteInformationProvider? routeProvider;
  @override
  State<TreemapExampleApp> createState() => _TreemapExampleAppState();
}

class _TreemapExampleAppState extends State<TreemapExampleApp> {
  late final PlaygroundStore _store;
  late final PlaygroundRouterDelegate _delegate;
  late final RouteInformationProvider _provider;
  String _theme = 'light';
  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialUri ??
        Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    _store =
        widget.store ??
        PlaygroundStore(initial: PlaygroundLocationCodec.decode(initial));
    _theme = _store.preview.text('environment.theme');
    _delegate = PlaygroundRouterDelegate(_store);
    _provider =
        widget.routeProvider ??
        PlaygroundRouteProvider(
          store: _store,
          initialRouteInformation: RouteInformation(
            uri:
                widget.initialUri ??
                (widget.store == null ? initial : _store.location.uri),
          ),
        );
    _store.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    final next = _store.preview.text('environment.theme');
    if (_theme != next && mounted) setState(() => _theme = next);
  }

  @override
  void dispose() {
    _store.removeListener(_onThemeChanged);
    _delegate.dispose();
    if (widget.routeProvider == null) {
      (_provider as PlaygroundRouteProvider).dispose();
    }
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF5061A7),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF5061A7),
      useMaterial3: true,
    ),
    themeMode: _theme == 'dark'
        ? ThemeMode.dark
        : _theme == 'system'
        ? ThemeMode.system
        : ThemeMode.light,
    routeInformationProvider: _provider,
    routeInformationParser: const PlaygroundRouteParser(),
    routerDelegate: _delegate,
  );
}
