enum QueryStatus { idle, loading, success, error }

const Object _queryStateUnset = Object();

class QueryState<T> {
  const QueryState({
    required this.status,
    required this.hasData,
    this.data,
    this.error,
    this.stackTrace,
    this.isFetching = false,
    this.isStale = false,
    this.dataUpdatedAt,
    this.errorUpdatedAt,
    this.lastFetchStartedAt,
    this.lastFetchCompletedAt,
    this.failureCount = 0,
  });

  final QueryStatus status;
  final bool hasData;
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isFetching;
  final bool isStale;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;
  final DateTime? lastFetchStartedAt;
  final DateTime? lastFetchCompletedAt;
  final int failureCount;

  bool get isIdle => status == QueryStatus.idle && !isFetching && !hasData;
  bool get isLoading => status == QueryStatus.loading;
  bool get isSuccess => status == QueryStatus.success;
  bool get isError => status == QueryStatus.error;
  bool get isInitialLoading => isLoading && !hasData;
  bool get isBackgroundFetching => isFetching && hasData;
  bool get isInitialError => isError && !hasData;
  bool get isRefreshError => isError && hasData;

  QueryState<T> copyWith({
    QueryStatus? status,
    Object? data = _queryStateUnset,
    bool? hasData,
    Object? error = _queryStateUnset,
    Object? stackTrace = _queryStateUnset,
    bool? isFetching,
    bool? isStale,
    Object? dataUpdatedAt = _queryStateUnset,
    Object? errorUpdatedAt = _queryStateUnset,
    Object? lastFetchStartedAt = _queryStateUnset,
    Object? lastFetchCompletedAt = _queryStateUnset,
    int? failureCount,
  }) {
    return QueryState<T>(
      status: status ?? this.status,
      hasData: hasData ?? this.hasData,
      data: data == _queryStateUnset ? this.data : data as T?,
      error: error == _queryStateUnset ? this.error : error,
      stackTrace: stackTrace == _queryStateUnset
          ? this.stackTrace
          : stackTrace as StackTrace?,
      isFetching: isFetching ?? this.isFetching,
      isStale: isStale ?? this.isStale,
      dataUpdatedAt: dataUpdatedAt == _queryStateUnset
          ? this.dataUpdatedAt
          : dataUpdatedAt as DateTime?,
      errorUpdatedAt: errorUpdatedAt == _queryStateUnset
          ? this.errorUpdatedAt
          : errorUpdatedAt as DateTime?,
      lastFetchStartedAt: lastFetchStartedAt == _queryStateUnset
          ? this.lastFetchStartedAt
          : lastFetchStartedAt as DateTime?,
      lastFetchCompletedAt: lastFetchCompletedAt == _queryStateUnset
          ? this.lastFetchCompletedAt
          : lastFetchCompletedAt as DateTime?,
      failureCount: failureCount ?? this.failureCount,
    );
  }
}
