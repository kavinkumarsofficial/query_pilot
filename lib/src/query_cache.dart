import 'query_controller.dart';
import 'query_key.dart';

class QueryCache {
  final Map<QueryKey, QueryController<dynamic>> _controllers = {};

  QueryController<T>? get<T>(List<Object?> key) {
    return _controllers[QueryKey.fromList(key)] as QueryController<T>?;
  }

  QueryController<dynamic>? getByQueryKey(QueryKey key) => _controllers[key];

  void put(QueryController<dynamic> controller) {
    _controllers[controller.queryKey] = controller;
  }

  void remove(QueryKey key) {
    _controllers.remove(key);
  }

  Iterable<QueryController<dynamic>> get values => _controllers.values;

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

  void clear() {
    final controllers = _controllers.values.toList(growable: false);
    _controllers.clear();
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
