import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:query_pilot/query_pilot.dart';

void main() {
  test('covers initial loading, success, and refresh error', () async {
    var now = DateTime.utc(2026, 1, 1);
    final pilot = QueryPilot(now: () => now);
    final first = Completer<List<int>>();
    final second = Completer<List<int>>();
    var callCount = 0;
    var useSecond = false;

    final controller = pilot.query<List<int>>(
      queryKey: const ['appointments'],
      queryFn: () {
        callCount += 1;
        return useSecond ? second.future : first.future;
      },
      options: const QueryOptions(
        staleTime: Duration(seconds: 30),
        cacheTime: Duration(minutes: 5),
      ),
    );

    await Future<void>.delayed(Duration.zero);
    expect(controller.state.isInitialLoading, isTrue);
    expect(callCount, 1);

    first.complete(const [1, 2]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.isSuccess, isTrue);
    expect(controller.state.data, const [1, 2]);

    controller.addListener(() {});
    now = now.add(const Duration(seconds: 31));
    useSecond = true;
    controller.onFocus();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.isBackgroundFetching, isTrue);
    expect(controller.state.data, const [1, 2]);
    expect(callCount, 2);

    second.completeError(StateError('refresh failed'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.isRefreshError, isTrue);
    expect(controller.state.data, const [1, 2]);
    expect(controller.state.error, isA<StateError>());
  });

  test(
    'uses fresh cache without refetching until stale unless configured',
    () async {
      var now = DateTime.utc(2026, 1, 1);
      final pilot = QueryPilot(now: () => now);
      var callCount = 0;

      final controller = pilot.query<String>(
        queryKey: const ['profile'],
        queryFn: () {
          callCount += 1;
          return Future<String>.value('alice');
        },
        options: const QueryOptions(staleTime: Duration(hours: 1)),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.data, 'alice');
      expect(callCount, 1);

      controller.addListener(() {});
      controller.onFocus();
      await Future<void>.delayed(Duration.zero);
      expect(callCount, 1);

      now = now.add(const Duration(hours: 2));
      controller.onFocus();
      await Future<void>.delayed(Duration.zero);
      expect(callCount, 2);
    },
  );

  test('allows fresh focus refetch when configured', () async {
    final pilot = QueryPilot();
    var callCount = 0;

    final controller = pilot.query<int>(
      queryKey: const ['fresh-focus'],
      queryFn: () {
        callCount += 1;
        return Future<int>.value(callCount);
      },
      options: const QueryOptions(
        staleTime: Duration(hours: 1),
        refetchOnFocusWhenFresh: true,
      ),
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    controller.addListener(() {});
    controller.onFocus();
    await Future<void>.delayed(Duration.zero);
    expect(callCount, 2);
  });

  test('deduplicates concurrent fetches and retries with policy', () async {
    final pilot = QueryPilot();
    var fetchCount = 0;
    final gate = Completer<String>();

    final controller = pilot.query<String>(
      queryKey: const ['dedupe'],
      queryFn: () {
        fetchCount += 1;
        return gate.future;
      },
      options: const QueryOptions(enabled: false),
    );

    final first = controller.fetch(force: true);
    final second = controller.fetch(force: true);
    expect(identical(first, second), isTrue);
    expect(fetchCount, 1);
    gate.complete('done');
    expect(await first, 'done');

    var retryCalls = 0;
    final retryController = pilot.query<String>(
      queryKey: const ['retry'],
      queryFn: () {
        retryCalls += 1;
        if (retryCalls == 1) {
          throw StateError('try again');
        }
        return 'ok';
      },
      options: const QueryOptions(
        enabled: false,
        retryPolicy: RetryPolicy(maxRetries: 1),
      ),
    );

    expect(await retryController.fetch(force: true), 'ok');
    expect(retryCalls, 2);
  });

  test('supports prefix invalidation, rollback, and cache clearing', () async {
    final pilot = QueryPilot();

    final listController = pilot.query<List<String>>(
      queryKey: const ['appointments'],
      queryFn: () => Future<List<String>>.value(const ['A']),
      options: const QueryOptions(enabled: false),
    );
    final detailController = pilot.query<String>(
      queryKey: const ['appointments', '1'],
      queryFn: () => Future<String>.value('A'),
      options: const QueryOptions(enabled: false),
    );

    listController.updateData((_) => const ['A']);
    detailController.updateData((_) => 'A');

    pilot.invalidateQueries(
      const ['appointments'],
      exact: false,
      refetch: false,
    );
    expect(listController.state.isStale, isTrue);
    expect(detailController.state.isStale, isTrue);

    final mutation = pilot.mutation<void, String>(
      mutationFn: (value) async {
        throw StateError('cancel failed');
      },
      options: MutationOptions<void, String>(
        optimisticUpdate: (pilot, value) {
          final previous = pilot
              .getQuery<List<String>>(const ['appointments'])
              ?.state
              .data;
          pilot.updateQueryData<List<String>>(const [
            'appointments',
          ], (current) => [...?current, value]);
          return () {
            pilot.updateQueryData<List<String>>(const [
              'appointments',
            ], (_) => previous);
          };
        },
      ),
    );

    await expectLater(mutation.execute('B'), throwsStateError);
    expect(listController.state.data, const ['A']);

    pilot.clear();
    expect(pilot.getQuery<List<String>>(const ['appointments']), isNull);
  });

  test('drops inactive cache entries after cache time elapses', () async {
    final pilot = QueryPilot();
    final controller = pilot.query<int>(
      queryKey: const ['gc'],
      queryFn: () => Future<int>.value(1),
      options: const QueryOptions(enabled: false, cacheTime: Duration.zero),
    );

    void listener() {}

    controller.addListener(listener);
    controller.updateData((_) => 1);
    controller.removeListener(listener);

    expect(pilot.getQuery<int>(const ['gc']), isNull);
  });
}
