import 'retry_policy.dart';

/// Configuration options for controlling query execution, caching, and lifecycle refreshes.
class QueryOptions {
  /// Creates a set of [QueryOptions].
  const QueryOptions({
    this.enabled = true,
    this.staleTime = Duration.zero,
    this.cacheTime = const Duration(minutes: 5),
    this.refetchOnMount = true,
    this.refetchOnFocus = true,
    this.refetchOnFocusWhenFresh = false,
    this.refetchOnResume = true,
    this.refetchOnResumeWhenFresh = false,
    this.retryPolicy = const RetryPolicy.none(),
  });

  /// Whether the query is actively enabled to fetch data.
  final bool enabled;

  /// The duration data remains fresh before becoming stale.
  final Duration staleTime;

  /// The duration inactive queries are kept in memory before being garbage collected.
  final Duration cacheTime;

  /// Whether stale queries should refetch when a new subscriber mounts.
  final bool refetchOnMount;

  /// Whether the query should refetch when its route regains navigation focus.
  final bool refetchOnFocus;

  /// Whether to refetch on focus even if data is still fresh within [staleTime].
  final bool refetchOnFocusWhenFresh;

  /// Whether the query should refetch when the app resumes from the background.
  final bool refetchOnResume;

  /// Whether to refetch on app resume even if data is still fresh within [staleTime].
  final bool refetchOnResumeWhenFresh;

  /// Retry configuration applied when query execution encounters an error.
  final RetryPolicy retryPolicy;

  @override
  bool operator ==(Object other) =>
      other is QueryOptions &&
      other.enabled == enabled &&
      other.staleTime == staleTime &&
      other.cacheTime == cacheTime &&
      other.refetchOnMount == refetchOnMount &&
      other.refetchOnFocus == refetchOnFocus &&
      other.refetchOnFocusWhenFresh == refetchOnFocusWhenFresh &&
      other.refetchOnResume == refetchOnResume &&
      other.refetchOnResumeWhenFresh == refetchOnResumeWhenFresh &&
      other.retryPolicy == retryPolicy;

  @override
  int get hashCode => Object.hash(
    enabled,
    staleTime,
    cacheTime,
    refetchOnMount,
    refetchOnFocus,
    refetchOnFocusWhenFresh,
    refetchOnResume,
    refetchOnResumeWhenFresh,
    retryPolicy,
  );

  /// Creates a copy of this [QueryOptions] with optional overrides.
  QueryOptions copyWith({
    bool? enabled,
    Duration? staleTime,
    Duration? cacheTime,
    bool? refetchOnMount,
    bool? refetchOnFocus,
    bool? refetchOnFocusWhenFresh,
    bool? refetchOnResume,
    bool? refetchOnResumeWhenFresh,
    RetryPolicy? retryPolicy,
  }) {
    return QueryOptions(
      enabled: enabled ?? this.enabled,
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      refetchOnFocus: refetchOnFocus ?? this.refetchOnFocus,
      refetchOnFocusWhenFresh:
          refetchOnFocusWhenFresh ?? this.refetchOnFocusWhenFresh,
      refetchOnResume: refetchOnResume ?? this.refetchOnResume,
      refetchOnResumeWhenFresh:
          refetchOnResumeWhenFresh ?? this.refetchOnResumeWhenFresh,
      retryPolicy: retryPolicy ?? this.retryPolicy,
    );
  }
}
