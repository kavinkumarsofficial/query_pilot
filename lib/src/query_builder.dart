import 'dart:async';

import 'package:flutter/widgets.dart';

import 'query_controller.dart';
import 'query_key.dart';
import 'query_options.dart';
import 'query_pilot_core.dart';
import 'query_pilot_scope.dart';
import 'query_state.dart';

typedef QueryWidgetBuilder<T> =
    Widget Function(
      BuildContext context,
      QueryState<T> state,
      QueryController<T> controller,
    );

class QueryBuilder<T> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.options = const QueryOptions(),
    this.pilot,
  });

  final List<Object?> queryKey;
  final FutureOr<T> Function() queryFn;
  final QueryOptions options;
  final QueryWidgetBuilder<T> builder;
  final QueryPilot? pilot;

  @override
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>> with RouteAware {
  QueryController<T>? _controller;
  QueryPilotRouteObserver? _routeObserver;
  ModalRoute<dynamic>? _route;

  QueryPilot get _pilot => widget.pilot ?? QueryPilotScope.of(context);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRouteObserver();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pilot != widget.pilot ||
        QueryKey.fromList(oldWidget.queryKey) !=
            QueryKey.fromList(widget.queryKey) ||
        oldWidget.options != widget.options ||
        oldWidget.queryFn != widget.queryFn) {
      _detachController();
      _attachController();
    }
  }

  @override
  void dispose() {
    _detachRouteObserver();
    _detachController();
    super.dispose();
  }

  @override
  void didPush() {
    _controller?.onFocus();
  }

  @override
  void didPopNext() {
    _controller?.onFocus();
  }

  @override
  void didPushNext() {}

  @override
  void didPop() {}

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return widget.builder(context, controller.state, controller);
  }

  void _attachController() {
    final controller = _pilot.query<T>(
      queryKey: widget.queryKey,
      queryFn: widget.queryFn,
      options: widget.options,
    );
    if (_controller == controller) {
      return;
    }
    _controller?.removeListener(_handleControllerChanged);
    _controller = controller;
    _controller?.addListener(_handleControllerChanged);
    if (mounted) {
      setState(() {});
    }
  }

  void _detachController() {
    _controller?.removeListener(_handleControllerChanged);
    _controller = null;
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _attachRouteObserver() {
    final route = ModalRoute.of(context);
    final observer = _pilot.routeObserver;
    if (route == null || route == _route && observer == _routeObserver) {
      return;
    }
    _detachRouteObserver();
    _route = route;
    _routeObserver = observer;
    observer.subscribe(this, route);
  }

  void _detachRouteObserver() {
    final observer = _routeObserver;
    final route = _route;
    if (observer != null && route != null) {
      observer.unsubscribe(this);
    }
    _routeObserver = null;
    _route = null;
  }
}
