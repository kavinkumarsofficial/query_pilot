import 'dart:async';

import 'package:flutter/widgets.dart';

import 'query_cache.dart';
import 'query_controller.dart';
import 'query_key.dart';
import 'query_options.dart';
import 'mutation_controller.dart';

class QueryPilot {
  QueryPilot({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final QueryCache cache = QueryCache();
  late final QueryPilotRouteObserver routeObserver = QueryPilotRouteObserver();

  DateTime now() => _now();

  QueryController<T> query<T>({
    required List<Object?> queryKey,
    required FutureOr<T> Function() queryFn,
    QueryOptions options = const QueryOptions(),
  }) {
    final key = QueryKey.fromList(queryKey);
    final existing = cache.getByQueryKey(key);
    if (existing != null) {
      final typed = existing as QueryController<T>;
      typed.updateConfiguration(queryFn: queryFn, options: options);
      return typed;
    }
    final controller = QueryController<T>(
      pilot: this,
      queryKey: key,
      queryFn: queryFn,
      options: options,
    );
    cache.put(controller as QueryController<dynamic>);
    return controller;
  }

  MutationController<TData, TVariables> mutation<TData, TVariables>({
    required FutureOr<TData> Function(TVariables variables) mutationFn,
    MutationOptions<TData, TVariables> options = const MutationOptions(),
  }) {
    return MutationController<TData, TVariables>(
      pilot: this,
      mutationFn: mutationFn,
      options: options,
    );
  }

  QueryController<T>? getQuery<T>(List<Object?> queryKey) =>
      cache.get<T>(queryKey);

  void invalidateQuery(
    List<Object?> queryKey, {
    bool exact = true,
    bool refetch = true,
  }) {
    final key = QueryKey.fromList(queryKey);
    for (final controller in cache.matching(key, exact: exact)) {
      controller.invalidate(refetch: refetch);
    }
  }

  void invalidateQueries(
    List<Object?> queryKey, {
    bool exact = false,
    bool refetch = true,
  }) => invalidateQuery(queryKey, exact: exact, refetch: refetch);

  void clear() {
    cache.clear();
  }

  void updateQueryData<T>(
    List<Object?> queryKey,
    T? Function(T? current) updater,
  ) {
    final controller = cache.get<T>(queryKey);
    if (controller != null) {
      controller.updateData(updater);
    }
  }

  void handleAppResumed() {
    for (final controller in cache.values) {
      if (controller.hasActiveListeners) {
        controller.onResume();
      }
    }
  }

  void handleAppFocused() {
    for (final controller in cache.values) {
      if (controller.hasActiveListeners) {
        controller.onFocus();
      }
    }
  }
}

class QueryPilotRouteObserver extends RouteObserver<ModalRoute<dynamic>> {}
