import 'query_controller.dart';
import 'query_key.dart';

/// In-memory storage and manager for active and cached [QueryController] instances.
class QueryCache {
  final Map<QueryKey, QueryController<dynamic>> _controllers = {};

  /// Retrieves a typed [QueryController] for the given [key] segments, if cached.
  QueryController<T>? get<T>(List<Object?> key) {
    return _controllers[QueryKey.fromList(key)] as QueryController<T>?;
  }

  /// Retrieves a controller by its [QueryKey].
  QueryController<dynamic>? getByQueryKey(QueryKey key) => _controllers[key];

  /// Stores a [controller] into the cache keyed by its query key.
  void put(QueryController<dynamic> controller) {
    _controllers[controller.queryKey] = controller;
  }

  /// Removes the controller associated with [key] from the cache.
  void remove(QueryKey key) {
    _controllers.remove(key);
  }

  /// An iterable of all currently cached controllers.
  Iterable<QueryController<dynamic>> get values => _controllers.values;

  /// Returns controllers matching [key]. If [exact] is false, matches by prefix.
  Iterable<QueryController<dynamic>> matching(
    QueryKey key, {
    bool exact = true,
  }) {
    if (exact) {
      final controller = _controllers[key];
      return controller == null ? const [] : [controller];
    }
    return _controllers.values.where(
      (controller) => controller.queryKey.startsWith(key),
    );
  }

  /// Disposes and clears all controllers stored in the cache.
  void clear() {
    final controllers = _controllers.values.toList(growable: false);
    _controllers.clear();
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
