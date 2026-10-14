import 'dart:async';

import 'package:flutter/foundation.dart';

import 'query_key.dart';
import 'query_options.dart';
import 'query_state.dart';

class QueryController<T> extends ChangeNotifier {
  QueryController({
    required this.pilot,
    required this.queryKey,
    required this._queryFn,
    required this._options,
    QueryState<T>? initialState,
  }) : _state =
           initialState ??
           QueryState<T>(
             status: QueryStatus.idle,
             hasData: false,
             isFetching: false,
             isStale: false,
           ) {
    if (_options.enabled) {
      scheduleMicrotask(_maybeFetchOnCreate);
    }
  }

  final dynamic pilot;
  final QueryKey queryKey;

  FutureOr<T> Function() _queryFn;
  QueryOptions _options;
  QueryState<T> _state;
  bool _disposed = false;
  int _listenerCount = 0;
  int _requestId = 0;
  Future<T>? _inFlight;
  Timer? _gcTimer;
  bool _invalidated = false;

  QueryState<T> get state => _refreshStaleState();
  QueryOptions get options => _options;
  bool get isDisposed => _disposed;
  bool get hasActiveListeners => _listenerCount > 0;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listenerCount += 1;
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_listenerCount > 0) {
      _listenerCount -= 1;
    }
    if (_listenerCount == 0) {
      _scheduleGc();
    }
  }

  void updateConfiguration({
    FutureOr<T> Function()? queryFn,
    QueryOptions? options,
  }) {
    if (queryFn != null) {
      _queryFn = queryFn;
    }
    if (options != null) {
      _options = options;
    }
    state;
  }

  Future<T> fetch({
    bool force = false,
    bool background = false,
    bool onResume = false,
    bool onFocus = false,
  }) {
    if (_disposed) {
      return Future.error(StateError('QueryController is disposed.'));
    }
    if (_inFlight != null) {
      return _inFlight!;
    }
    if (!_options.enabled && !force) {
      return Future.error(StateError('Query is disabled.'));
    }

    final currentState = state;
    final shouldBackground = background || currentState.hasData;
    final requestId = ++_requestId;
    final startedAt = pilot.now();
    final loadingState = shouldBackground
        ? currentState.copyWith(
            isFetching: true,
            lastFetchStartedAt: startedAt,
            isStale: true,
          )
        : currentState.copyWith(
            status: QueryStatus.loading,
            isFetching: true,
            lastFetchStartedAt: startedAt,
            isStale: true,
          );
    _setState(loadingState);

    final completer = Completer<T>();
    _inFlight = completer.future;

    () async {
      try {
        final result = await _executeWithRetry();
        if (_disposed || requestId != _requestId) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
          return;
        }
        final completedAt = pilot.now();
        _invalidated = false;
        _setState(
          QueryState<T>(
            status: QueryStatus.success,
            hasData: true,
            data: result,
            isFetching: false,
            isStale: false,
            dataUpdatedAt: completedAt,
            lastFetchStartedAt: startedAt,
            lastFetchCompletedAt: completedAt,
            failureCount: 0,
          ),
        );
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (error, stackTrace) {
        if (_disposed || requestId != _requestId) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
          return;
        }
        final completedAt = pilot.now();
        final hasData = _state.hasData;
        _setState(
          _state.copyWith(
            status: QueryStatus.error,
            error: error,
            stackTrace: stackTrace,
            isFetching: false,
            isStale: true,
            errorUpdatedAt: completedAt,
            lastFetchStartedAt: startedAt,
            lastFetchCompletedAt: completedAt,
            failureCount: _state.failureCount + 1,
          ),
        );
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        if (!hasData) {
          _invalidated = true;
        }
      } finally {
        if (requestId == _requestId) {
          _inFlight = null;
        }
      }
    }();

    return completer.future;
  }

  Future<T> refetch() {
    final currentState = state;
    return fetch(force: true, background: currentState.hasData);
  }

  Future<T> retry() {
    final currentState = state;
    return fetch(force: true, background: currentState.hasData);
  }

  void invalidate({bool refetch = true}) {
    final currentState = state;
    _invalidated = true;
    _setState(_state.copyWith(isStale: true));
    if (refetch && hasActiveListeners && _options.enabled) {
      _triggerFetch(background: currentState.hasData);
    }
  }

  void onFocus() {
    final currentState = state;
    if (!_options.enabled || !_options.refetchOnFocus || !hasActiveListeners) {
      return;
    }
    if (currentState.hasData &&
        !_options.refetchOnFocusWhenFresh &&
        !currentState.isStale) {
      return;
    }
    _triggerFetch(background: currentState.hasData);
  }

  void onResume() {
    final currentState = state;
    if (!_options.enabled || !_options.refetchOnResume || !hasActiveListeners) {
      return;
    }
    if (currentState.hasData &&
        !_options.refetchOnResumeWhenFresh &&
        !currentState.isStale) {
      return;
    }
    _triggerFetch(background: currentState.hasData);
  }

  void markStale() {
    _invalidated = true;
    _setState(_state.copyWith(isStale: true));
  }

  void updateData(T? Function(T? current) updater) {
    final updated = updater(_state.data);
    _setState(
      _state.copyWith(
        status: QueryStatus.success,
        hasData: true,
        data: updated,
        isFetching: false,
        isStale: false,
        dataUpdatedAt: pilot.now(),
      ),
    );
    _invalidated = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _gcTimer?.cancel();
    _gcTimer = null;
    super.dispose();
  }

  Future<T> _executeWithRetry() async {
    final policy = _options.retryPolicy;
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await Future<T>.value(_queryFn());
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

  bool _shouldAutoFetchOnMount() {
    final currentState = state;
    if (!_options.enabled) {
      return false;
    }
    if (!currentState.hasData) {
      return true;
    }
    return _options.refetchOnMount && currentState.isStale;
  }

  void _maybeFetchOnCreate() {
    if (_disposed || !_options.enabled) {
      return;
    }
    final currentState = state;
    if (_shouldAutoFetchOnMount()) {
      _triggerFetch(background: currentState.hasData);
    }
  }

  void _triggerFetch({required bool background}) {
    unawaited(
      fetch(
        background: background,
      ).then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {}),
    );
  }

  QueryState<T> _refreshStaleState({bool notify = false}) {
    final stale = _invalidated || _isStaleByAge();
    if (_state.isStale != stale) {
      _state = _state.copyWith(isStale: stale);
      if (notify) {
        notifyListeners();
      }
    }
    return _state;
  }

  bool _isStaleByAge() {
    final updatedAt = _state.dataUpdatedAt;
    if (updatedAt == null) {
      return true;
    }
    return pilot.now().difference(updatedAt) > _options.staleTime;
  }

  void _setState(QueryState<T> next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _state = _refreshStaleState();
    notifyListeners();
  }

  void _scheduleGc() {
    _gcTimer?.cancel();
    final cacheTime = _options.cacheTime;
    if (cacheTime <= Duration.zero) {
      _disposeFromCache();
      return;
    }
    _gcTimer = Timer(cacheTime, _disposeFromCache);
  }

  void _disposeFromCache() {
    if (_listenerCount > 0 || _disposed) {
      return;
    }
    pilot.cache.remove(queryKey);
    dispose();
  }
}
