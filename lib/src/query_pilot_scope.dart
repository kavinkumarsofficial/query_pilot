import 'package:flutter/widgets.dart';

import 'query_pilot_core.dart';

class QueryPilotScope extends StatefulWidget {
  const QueryPilotScope({super.key, required this.pilot, required this.child});

  final QueryPilot pilot;
  final Widget child;

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
