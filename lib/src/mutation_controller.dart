// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'query_pilot_core.dart';
import 'retry_policy.dart';

/// Callback invoked to undo an optimistic mutation update if execution fails.
typedef MutationRollback = FutureOr<void> Function();

/// Options configuring mutation behavior, optimistic updates, and cache invalidation.
class MutationOptions<TData, TVariables> {
  /// Creates a set of [MutationOptions].
  const MutationOptions({
    this.retryPolicy = const RetryPolicy.none(),
    this.invalidateExactKeys = const <List<Object?>>[],
    this.invalidatePrefixKeys = const <List<Object?>>[],
    this.optimisticUpdate,
    this.onSuccess,
    this.onError,
  });

  /// Retry configuration applied when mutation execution encounters an error.
  final RetryPolicy retryPolicy;

  /// Specific query keys to invalidate when the mutation completes successfully.
  final List<List<Object?>> invalidateExactKeys;

  /// Query key prefixes to invalidate when the mutation completes successfully.
  final List<List<Object?>> invalidatePrefixKeys;

  /// Hook to apply optimistic state changes before the mutation runs.
  ///
  /// Should return an optional [MutationRollback] function to revert changes if the mutation fails.
  final FutureOr<MutationRollback?> Function(
    QueryPilot pilot,
    TVariables variables,
  )?
  optimisticUpdate;

  /// Callback executed when the mutation succeeds.
  final FutureOr<void> Function(
    QueryPilot pilot,
    TData data,
    TVariables variables,
  )?
  onSuccess;

  /// Callback executed when the mutation fails.
  final FutureOr<void> Function(
    QueryPilot pilot,
    Object error,
    StackTrace stackTrace,
    TVariables variables,
  )?
  onError;
}

/// Lifecycle status for a mutation.
enum MutationStatus {
  /// The mutation has not been triggered yet.
  idle,

  /// The mutation is actively executing.
  pending,

  /// The mutation finished successfully.
  success,

  /// The mutation encountered an error.
  error,
}

/// Snapshot of the current state of a mutation.
class MutationState<TData, TVariables> {
  /// Creates a [MutationState].
  const MutationState({
    required this.status,
    this.data,
    this.variables,
    this.error,
    this.stackTrace,
  });

  /// The current lifecycle status of the mutation.
  final MutationStatus status;

  /// The data returned by the mutation, if successful.
  final TData? data;

  /// The variables provided to the most recent mutation execution.
  final TVariables? variables;

  /// The error thrown during mutation execution, if any.
  final Object? error;

  /// The stack trace associated with [error], if any.
  final StackTrace? stackTrace;

  /// Whether the mutation is currently idle.
  bool get isIdle => status == MutationStatus.idle;

  /// Whether the mutation is currently running.
  bool get isPending => status == MutationStatus.pending;

  /// Whether the mutation completed with success.
  bool get isSuccess => status == MutationStatus.success;

  /// Whether the mutation resulted in an error.
  bool get isError => status == MutationStatus.error;
}

/// Controller that coordinates asynchronous mutations, optimistic updates, and rollbacks.
class MutationController<TData, TVariables> extends ChangeNotifier {
  /// Creates a [MutationController].
  MutationController({
    required this.pilot,
    required FutureOr<TData> Function(TVariables variables) mutationFn,
    required MutationOptions<TData, TVariables> options,
  }) : _mutationFn = mutationFn,
       _options = options,
       _state = MutationState<TData, TVariables>(status: MutationStatus.idle);

  /// The [QueryPilot] instance managing queries and cache.
  final QueryPilot pilot;

  final FutureOr<TData> Function(TVariables variables) _mutationFn;
  final MutationOptions<TData, TVariables> _options;
  MutationState<TData, TVariables> _state;
  Future<TData>? _inFlight;

  /// The current mutation state snapshot.
  MutationState<TData, TVariables> get state => _state;

  /// The active mutation options.
  MutationOptions<TData, TVariables> get options => _options;

  /// Executes the mutation with the given [variables].
  Future<TData> execute(TVariables variables) {
    if (_inFlight != null) {
      return _inFlight!;
    }
    final completer = Completer<TData>();
    _inFlight = completer.future;
    _state = MutationState<TData, TVariables>(
      status: MutationStatus.pending,
      variables: variables,
    );
    notifyListeners();

    () async {
      MutationRollback? rollback;
      try {
        rollback = await _options.optimisticUpdate?.call(pilot, variables);
        final result = await _executeWithRetry(variables);
        _state = MutationState<TData, TVariables>(
          status: MutationStatus.success,
          data: result,
          variables: variables,
        );
        notifyListeners();
        for (final key in _options.invalidateExactKeys) {
          pilot.invalidateQuery(key, exact: true, refetch: true);
        }
        for (final key in _options.invalidatePrefixKeys) {
          pilot.invalidateQuery(key, exact: false, refetch: true);
        }
        await _options.onSuccess?.call(pilot, result, variables);
        completer.complete(result);
      } catch (error, stackTrace) {
        if (rollback != null) {
          await rollback();
        }
        _state = MutationState<TData, TVariables>(
          status: MutationStatus.error,
          error: error,
          stackTrace: stackTrace,
          variables: variables,
        );
        notifyListeners();
        await _options.onError?.call(pilot, error, stackTrace, variables);
        completer.completeError(error, stackTrace);
      } finally {
        _inFlight = null;
      }
    }();

    return completer.future;
  }

  Future<TData> _executeWithRetry(TVariables variables) async {
    final policy = _options.retryPolicy;
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await Future<TData>.value(_mutationFn(variables));
      } catch (error, stackTrace) {
        final shouldRetry =
            attempt <= policy.maxRetries &&
            (policy.shouldRetry?.call(error, stackTrace, attempt) ?? true);
        if (!shouldRetry) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        final delay = policy.delayBuilder(attempt);
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }
  }
}
