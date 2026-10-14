import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'location.dart';
import 'page.dart';
import 'store.dart';

class PlaygroundRouteParser extends RouteInformationParser<PlaygroundLocation> {
  const PlaygroundRouteParser();
  @override
  Future<PlaygroundLocation> parseRouteInformation(
    RouteInformation routeInformation,
  ) => SynchronousFuture(PlaygroundLocationCodec.decode(routeInformation.uri));
  @override
  RouteInformation restoreRouteInformation(PlaygroundLocation configuration) =>
      RouteInformation(uri: configuration.uri);
}

/// Canonicalization and drafts replace; completed edits explicitly push.
class PlaygroundRouteProvider extends PlatformRouteInformationProvider {
  PlaygroundRouteProvider({
    required super.initialRouteInformation,
    required this.store,
  });
  final PlaygroundStore store;
  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    final intent = store.historyIntent;
    store.historyIntent = HistoryIntent.replace;
    super.routerReportsNewRouteInformation(
      routeInformation,
      type: intent == HistoryIntent.push
          ? RouteInformationReportingType.navigate
          : RouteInformationReportingType.neglect,
    );
  }
}

class PlaygroundRouterDelegate extends RouterDelegate<PlaygroundLocation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<PlaygroundLocation> {
  PlaygroundRouterDelegate(this.store) {
    store.addListener(notifyListeners);
  }
  final PlaygroundStore store;
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  PlaygroundLocation get currentConfiguration => store.location;
  @override
  Future<void> setNewRoutePath(PlaygroundLocation configuration) {
    store.restore(configuration);
    return SynchronousFuture(null);
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      MaterialPage<void>(
        key: const ValueKey('playground'),
        child: PlaygroundPage(store: store),
      ),
    ],
    onDidRemovePage: (_) {},
  );
  @override
  void dispose() {
    store.removeListener(notifyListeners);
    super.dispose();
  }
}
