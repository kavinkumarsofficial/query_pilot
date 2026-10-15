/// A structured, composite key used to uniquely identify queries in [QueryCache].
class QueryKey {
  /// Creates a [QueryKey] with the given [segments].
  QueryKey(Iterable<Object?> segments)
    : segments = List<Object?>.unmodifiable(segments);

  /// Creates a [QueryKey] from a list of [segments].
  factory QueryKey.fromList(List<Object?> segments) => QueryKey(segments);

  /// The immutable list of segments identifying this query.
  final List<Object?> segments;

  /// Returns `true` if this key starts with all segments in [prefix].
  bool startsWith(QueryKey prefix) {
    if (prefix.segments.length > segments.length) {
      return false;
    }
    for (var i = 0; i < prefix.segments.length; i++) {
      if (!_deepEquals(segments[i], prefix.segments[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is QueryKey && _deepEquals(segments, other.segments);

  @override
  int get hashCode => _deepHash(segments);

  @override
  String toString() => 'QueryKey(${segments.join(', ')})';
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (!_deepEquals(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is Set && right is Set) {
    if (left.length != right.length) {
      return false;
    }
    return left.every(
      (value) => right.any((candidate) => _deepEquals(value, candidate)),
    );
  }
  return left == right;
}

int _deepHash(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is List) {
    return Object.hashAll(value.map(_deepHash));
  }
  if (value is Map) {
    return Object.hashAll(
      value.entries.map(
        (entry) => Object.hash(_deepHash(entry.key), _deepHash(entry.value)),
      ),
    );
  }
  if (value is Set) {
    return Object.hashAll(value.map(_deepHash).toList()..sort());
  }
  return value.hashCode;
}
