/// High-level lifecycle status of a query.
enum QueryStatus {
  /// The query has not initiated a fetch yet.
  idle,

  /// The query is actively executing its fetch function.
  loading,

  /// The query successfully fetched or contains valid cached data.
  success,

  /// The query fetch failed with an error.
  error,
}

const Object _queryStateUnset = Object();

/// Snapshot of the current state of a query, including cached data and status flags.
class QueryState<T> {
  /// Creates a [QueryState].
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

  /// The current lifecycle status of the query.
  final QueryStatus status;

  /// Whether valid data is present in this state.
  final bool hasData;

  /// The most recent cached data, or null.
  final T? data;

  /// The error thrown by the most recent fetch attempt, if any.
  final Object? error;

  /// The stack trace associated with [error], if any.
  final StackTrace? stackTrace;

  /// Whether an active network or asynchronous fetch is in progress.
  final bool isFetching;

  /// Whether the data is considered stale based on staleTime or manual invalidation.
  final bool isStale;

  /// Timestamp when data was last successfully fetched or updated.
  final DateTime? dataUpdatedAt;

  /// Timestamp when an error was last encountered.
  final DateTime? errorUpdatedAt;

  /// Timestamp when the last fetch attempt started.
  final DateTime? lastFetchStartedAt;

  /// Timestamp when the last fetch attempt completed.
  final DateTime? lastFetchCompletedAt;

  /// Number of consecutive fetch failures for this query.
  final int failureCount;

  /// Whether the query is in an un-triggered idle state without cached data.
  bool get isIdle => status == QueryStatus.idle && !isFetching && !hasData;

  /// Whether the query status is currently loading.
  bool get isLoading => status == QueryStatus.loading;

  /// Whether the query successfully completed.
  bool get isSuccess => status == QueryStatus.success;

  /// Whether the query status is currently error.
  bool get isError => status == QueryStatus.error;

  /// Whether the query is loading for the first time without any prior cached data.
  bool get isInitialLoading => isLoading && !hasData;

  /// Whether a refetch is executing in the background while previous cached data is still displayed.
  bool get isBackgroundFetching => isFetching && hasData;

  /// Whether the query errored with no cached data to display.
  bool get isInitialError => isError && !hasData;

  /// Whether a background refetch failed while previous cached data remains available.
  bool get isRefreshError => isError && hasData;

  /// Returns a copy of this [QueryState] with updated properties.
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
