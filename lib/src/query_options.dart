import 'retry_policy.dart';

class QueryOptions {
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

  final bool enabled;
  final Duration staleTime;
  final Duration cacheTime;
  final bool refetchOnMount;
  final bool refetchOnFocus;
  final bool refetchOnFocusWhenFresh;
  final bool refetchOnResume;
  final bool refetchOnResumeWhenFresh;
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
