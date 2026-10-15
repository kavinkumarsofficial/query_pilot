import 'dart:async';

import 'package:flutter/widgets.dart';

import 'mutation_controller.dart';
import 'query_cache.dart';
import 'query_controller.dart';
import 'query_key.dart';
import 'query_options.dart';

/// The central coordinator that owns the [QueryCache], creates queries/mutations, and manages invalidation.
class QueryPilot {
  /// Creates a [QueryPilot] instance. An optional custom [now] clock function can be provided for testing.
  QueryPilot({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// The cache holding all active and retained [QueryController] instances.
  final QueryCache cache = QueryCache();

  /// Route observer to plug into [MaterialApp.navigatorObservers] for automatic focus refetching.
  late final QueryPilotRouteObserver routeObserver = QueryPilotRouteObserver();

  /// Returns the current timestamp according to the clock provider.
  DateTime now() => _now();

  /// Creates or retrieves a cached [QueryController] for the given [queryKey].
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

  /// Creates a [MutationController] for performing typed async operations.
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

  /// Retrieves an existing cached [QueryController] for [queryKey], or returns null if not present.
  QueryController<T>? getQuery<T>(List<Object?> queryKey) =>
      cache.get<T>(queryKey);

  /// Marks matching query entries as invalidated and optionally initiates a background refetch.
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

  /// Invalidates queries matching [queryKey]. By default matches prefix segments ([exact] is false).
  void invalidateQueries(
    List<Object?> queryKey, {
    bool exact = false,
    bool refetch = true,
  }) => invalidateQuery(queryKey, exact: exact, refetch: refetch);

  /// Clears all entries in [cache] and disposes cached controllers.
  void clear() {
    cache.clear();
  }

  /// Directly updates cached data for [queryKey] using the [updater] transform function.
  void updateQueryData<T>(
    List<Object?> queryKey,
    T? Function(T? current) updater,
  ) {
    final controller = cache.get<T>(queryKey);
    if (controller != null) {
      controller.updateData(updater);
    }
  }

  /// Notifies active controllers with listeners that the host application resumed.
  void handleAppResumed() {
    for (final controller in cache.values) {
      if (controller.hasActiveListeners) {
        controller.onResume();
      }
    }
  }

  /// Notifies active controllers with listeners that route focus returned.
  void handleAppFocused() {
    for (final controller in cache.values) {
      if (controller.hasActiveListeners) {
        controller.onFocus();
      }
    }
  }
}

/// A [RouteObserver] that tracks route navigation to notify [QueryBuilder] when screens regain focus.
class QueryPilotRouteObserver extends RouteObserver<ModalRoute<dynamic>> {}
