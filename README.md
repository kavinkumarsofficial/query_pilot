# QueryPilot

Fetch smart. Cache right. Stay fresh.

QueryPilot is a Flutter server-state package for caching, stale-time handling, background refetching, typed mutations, and route/app-lifecycle aware refreshes.

## Install

```yaml
dependencies:
  query_pilot: ^1.0.1
```

## Quick start

```dart
final pilot = QueryPilot();

final appointments = pilot.query<List<Appointment>>(
  queryKey: const ['appointments'],
  queryFn: api.getAppointments,
  options: const QueryOptions(
    staleTime: Duration(seconds: 30),
    refetchOnFocus: true,
    refetchOnResume: true,
  ),
);
```

## Widget integration

```dart
QueryPilotScope(
  pilot: pilot,
  child: MaterialApp(
    navigatorObservers: [pilot.routeObserver],
    home: const AppHome(),
  ),
);
```

```dart
QueryBuilder<List<Appointment>>(
  queryKey: const ['appointments'],
  queryFn: api.getAppointments,
  builder: (context, state, controller) {
    if (state.isInitialLoading) {
      return const CircularProgressIndicator();
    }

    if (state.isInitialError && !state.hasData) {
      return Text('${state.error}');
    }

    return RefreshIndicator(
      onRefresh: () async => controller.refetch(),
      child: ListView(
        children: [
          if (state.isBackgroundFetching) const LinearProgressIndicator(),
          for (final item in state.data ?? const []) ListTile(title: Text(item.title)),
        ],
      ),
    );
  },
);
```

## API reference

- `QueryPilot` owns the cache and creates queries/mutations.
- `QueryController<T>` exposes `state`, `refetch`, `retry`, `invalidate`, and lifecycle hooks.
- `QueryOptions` controls stale time, cache time, focus/resume refetching, and retry policy.
- `QueryState<T>` tracks idle/loading/success/error, timestamps, and fetching flags.
- `QueryCache` stores controllers by stable query key.
- `MutationController<TData, TVariables>` handles typed mutations, optimistic updates, and rollback.
- `QueryBuilder<T>` bridges a query into the widget tree.

## Configuration

`QueryOptions` supports:

- `staleTime`
- `cacheTime`
- `refetchOnMount`
- `refetchOnFocus`
- `refetchOnFocusWhenFresh`
- `refetchOnResume`
- `refetchOnResumeWhenFresh`
- `retryPolicy`

## Caching and invalidation

```dart
pilot.updateQueryData<List<Appointment>>(
  const ['appointments'],
  (current) => [...?current, newAppointment],
);

pilot.invalidateQuery(const ['appointments']);
pilot.invalidateQueries(const ['appointments'], exact: false);
```

## Mutations

```dart
final mutation = pilot.mutation<void, String>(
  mutationFn: api.cancelAppointment,
  options: MutationOptions<void, String>(
    invalidateExactKeys: const [
      ['appointments'],
    ],
    optimisticUpdate: (pilot, id) {
      final previous = pilot.getQuery<List<Appointment>>(const ['appointments'])?.state.data;
      pilot.updateQueryData<List<Appointment>>(
        const ['appointments'],
        (current) => [
          for (final item in current ?? const <Appointment>[])
            if (item.id == id) item.copyWith(cancelled: true) else item,
        ],
      );
      return () => pilot.updateQueryData<List<Appointment>>(const ['appointments'], (_) => previous);
    },
  ),
);
```

## Navigation and resume integration

1. Wrap the app in `QueryPilotScope`.
2. Pass `pilot.routeObserver` to `MaterialApp.navigatorObservers`.
3. Use `QueryBuilder` on the screens that own the query.
4. Back navigation triggers focus refetch for the route that becomes visible.
5. App resume triggers lifecycle refetch for observed queries.

## Example app

Run the complete sample app:

```bash
flutter run -t example/lib/main.dart
```

It demonstrates:

- loading, success, empty, and error states
- cache-first rendering
- stale-time and background refetching
- retry behavior
- list/detail navigation and refetch-on-focus
- optimistic mutation updates and rollback

## Limitations

- QueryPilot is client-side only; it does not detect server changes without a refetch trigger.
- Persistence, polling, WebSocket push invalidation, and ETag integration are not included yet.

## Troubleshooting

- If focus refetch does nothing, confirm `pilot.routeObserver` is registered on `MaterialApp`.
- If resume refetch does nothing, confirm the app is wrapped in `QueryPilotScope`.
- If the example fails to run, make sure you use `flutter run -t example/lib/main.dart`.

