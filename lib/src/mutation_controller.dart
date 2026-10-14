import 'dart:async';

import 'package:flutter/foundation.dart';

import 'query_pilot_core.dart';
import 'retry_policy.dart';

typedef MutationRollback = FutureOr<void> Function();

class MutationOptions<TData, TVariables> {
  const MutationOptions({
    this.retryPolicy = const RetryPolicy.none(),
    this.invalidateExactKeys = const <List<Object?>>[],
    this.invalidatePrefixKeys = const <List<Object?>>[],
    this.optimisticUpdate,
    this.onSuccess,
    this.onError,
  });

  final RetryPolicy retryPolicy;
  final List<List<Object?>> invalidateExactKeys;
  final List<List<Object?>> invalidatePrefixKeys;
  final FutureOr<MutationRollback?> Function(
    QueryPilot pilot,
    TVariables variables,
  )?
  optimisticUpdate;
  final FutureOr<void> Function(
    QueryPilot pilot,
    TData data,
    TVariables variables,
  )?
  onSuccess;
  final FutureOr<void> Function(
    QueryPilot pilot,
    Object error,
    StackTrace stackTrace,
    TVariables variables,
  )?
  onError;
}

enum MutationStatus { idle, pending, success, error }

class MutationState<TData, TVariables> {
  const MutationState({
    required this.status,
    this.data,
    this.variables,
    this.error,
    this.stackTrace,
  });

  final MutationStatus status;
  final TData? data;
  final TVariables? variables;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isIdle => status == MutationStatus.idle;
  bool get isPending => status == MutationStatus.pending;
  bool get isSuccess => status == MutationStatus.success;
  bool get isError => status == MutationStatus.error;
}

class MutationController<TData, TVariables> extends ChangeNotifier {
  MutationController({
    required this.pilot,
    required this._mutationFn,
    required this._options,
  }) : _state = MutationState<TData, TVariables>(status: MutationStatus.idle);

  final QueryPilot pilot;

  final FutureOr<TData> Function(TVariables variables) _mutationFn;
  final MutationOptions<TData, TVariables> _options;
  MutationState<TData, TVariables> _state;
  Future<TData>? _inFlight;

  MutationState<TData, TVariables> get state => _state;
  MutationOptions<TData, TVariables> get options => _options;

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
