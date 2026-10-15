import 'package:flutter/widgets.dart';

import 'query_pilot_core.dart';

/// Provides a [QueryPilot] instance to descendants in the widget tree and listens to app lifecycle events.
class QueryPilotScope extends StatefulWidget {
  /// Creates a [QueryPilotScope].
  const QueryPilotScope({super.key, required this.pilot, required this.child});

  /// The [QueryPilot] client instance to provide down the widget tree.
  final QueryPilot pilot;

  /// The child widget.
  final Widget child;

  /// Obtains the closest [QueryPilot] instance from the given [context].
  ///
  /// Throws a [FlutterError] if no [QueryPilotScope] ancestor exists.
  static QueryPilot of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_QueryPilotInherited>();
    if (scope == null) {
      throw FlutterError(
        'QueryPilotScope.of() called with a context that does not contain a '
        'QueryPilotScope.',
      );
    }
    return scope.pilot;
  }

  /// Obtains the closest [QueryPilot] instance from the given [context], or null if none is found.
  static QueryPilot? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_QueryPilotInherited>()
        ?.pilot;
  }

  @override
  State<QueryPilotScope> createState() => _QueryPilotScopeState();
}

class _QueryPilotScopeState extends State<QueryPilotScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.pilot.handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _QueryPilotInherited(pilot: widget.pilot, child: widget.child);
  }
}

class _QueryPilotInherited extends InheritedWidget {
  const _QueryPilotInherited({required this.pilot, required super.child});

  final QueryPilot pilot;

  @override
  bool updateShouldNotify(_QueryPilotInherited oldWidget) =>
      pilot != oldWidget.pilot;
}
