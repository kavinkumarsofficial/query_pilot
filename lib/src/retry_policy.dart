import 'dart:math';

/// Function signature for computing delay before a retry attempt.
typedef RetryDelayBuilder = Duration Function(int retryAttempt);

/// Configures retry behavior for failed queries and mutations.
class RetryPolicy {
  /// Creates a custom [RetryPolicy].
  const RetryPolicy({
    this.maxRetries = 0,
    this.delayBuilder = _defaultDelayBuilder,
    this.shouldRetry,
  });

  /// Maximum number of retry attempts before giving up.
  final int maxRetries;

  /// Function that determines the wait duration before the given retry attempt.
  final RetryDelayBuilder delayBuilder;

  /// Optional predicate to determine if a specific error should be retried.
  final bool Function(Object error, StackTrace stackTrace, int retryAttempt)?
  shouldRetry;

  @override
  bool operator ==(Object other) =>
      other is RetryPolicy &&
      other.maxRetries == maxRetries &&
      other.delayBuilder == delayBuilder &&
      other.shouldRetry == shouldRetry;

  @override
  int get hashCode => Object.hash(maxRetries, delayBuilder, shouldRetry);

  /// Disables automatic retries.
  const factory RetryPolicy.none() = _NoRetryPolicy;

  /// Creates an exponential backoff retry policy.
  ///
  /// Delays start around [baseDelay] and double per attempt up to [maxDelay].
  factory RetryPolicy.exponential({
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 250),
    Duration maxDelay = const Duration(seconds: 5),
    bool Function(Object error, StackTrace stackTrace, int retryAttempt)?
    shouldRetry,
  }) {
    return RetryPolicy(
      maxRetries: maxRetries,
      delayBuilder: (retryAttempt) {
        final factor = pow(2, retryAttempt - 1).toInt();
        final delay = Duration(milliseconds: baseDelay.inMilliseconds * factor);
        return delay > maxDelay ? maxDelay : delay;
      },
      shouldRetry: shouldRetry,
    );
  }

  static Duration _defaultDelayBuilder(int retryAttempt) {
    return Duration(milliseconds: 250 * retryAttempt);
  }
}

class _NoRetryPolicy extends RetryPolicy {
  const _NoRetryPolicy() : super(maxRetries: 0);
}
