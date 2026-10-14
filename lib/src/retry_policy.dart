import 'dart:math';

typedef RetryDelayBuilder = Duration Function(int retryAttempt);

class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 0,
    this.delayBuilder = _defaultDelayBuilder,
    this.shouldRetry,
  });

  final int maxRetries;
  final RetryDelayBuilder delayBuilder;
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

  const factory RetryPolicy.none() = _NoRetryPolicy;

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
