import 'dart:async';

import 'package:flutter/material.dart';
import 'package:query_pilot/query_pilot.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final QueryPilot _pilot = QueryPilot();
  final ExampleRepository _repository = ExampleRepository();

  @override
  void dispose() {
    _pilot.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QueryPilotScope(
      pilot: _pilot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'QueryPilot Example',
        navigatorObservers: [_pilot.routeObserver],
        home: ExampleListScreen(repository: _repository),
      ),
    );
  }
}

class ExampleRepository {
  ExampleRepository() {
    _appointments = <ExampleAppointment>[
      const ExampleAppointment('1', 'Design review'),
      const ExampleAppointment('2', 'Team sync'),
    ];
  }

  late List<ExampleAppointment> _appointments;
  Completer<List<ExampleAppointment>>? _pendingFetch;
  bool _failNextFetch = false;
  bool _returnEmptyNextFetch = false;
  bool _failNextMutation = false;
  int fetchCount = 0;

  void queueUpdatedData(List<ExampleAppointment> items) {
    final completer = Completer<List<ExampleAppointment>>();
    _pendingFetch = completer;
    Future<void>.microtask(() => completer.complete(items));
  }

  void fetchReturnsErrorOnce() {
    _failNextFetch = true;
  }

  void fetchReturnsEmptyOnce() {
    _returnEmptyNextFetch = true;
  }

  void failNextMutation() {
    _failNextMutation = true;
  }

  Future<List<ExampleAppointment>> fetchAppointments() async {
    fetchCount += 1;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_failNextFetch) {
      _failNextFetch = false;
      throw StateError('Failed to load appointments.');
    }
    if (_returnEmptyNextFetch) {
      _returnEmptyNextFetch = false;
      return const <ExampleAppointment>[];
    }
    final pending = _pendingFetch;
    if (pending != null) {
      _pendingFetch = null;
      return pending.future;
    }
    return List<ExampleAppointment>.unmodifiable(_appointments);
  }

  Future<void> cancelAppointment(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (_failNextMutation) {
      _failNextMutation = false;
      throw StateError('Cancel failed.');
    }
    _appointments = [
      for (final appointment in _appointments)
        if (appointment.id == id)
          appointment.copyWith(cancelled: true)
        else
          appointment,
    ];
  }
}

class ExampleAppointment {
  const ExampleAppointment(this.id, this.title, {this.cancelled = false});

  final String id;
  final String title;
  final bool cancelled;

  ExampleAppointment copyWith({bool? cancelled}) {
    return ExampleAppointment(
      id,
      title,
      cancelled: cancelled ?? this.cancelled,
    );
  }
}

class ExampleListScreen extends StatelessWidget {
  const ExampleListScreen({super.key, required this.repository});

  final ExampleRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryPilot Example')),
      body: QueryBuilder<List<ExampleAppointment>>(
        queryKey: const ['appointments'],
        queryFn: repository.fetchAppointments,
        options: const QueryOptions(
          staleTime: Duration(seconds: 2),
          cacheTime: Duration(minutes: 5),
          refetchOnFocus: true,
          refetchOnResume: true,
        ),
        builder: (context, state, controller) {
          if (state.isInitialLoading && !state.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading appointments...'),
                ],
              ),
            );
          }

          if (state.isInitialError && !state.hasData) {
            return _ErrorPanel(
              message: '${state.error}',
              onRetry: () {
                unawaited(controller.retry());
              },
            );
          }

          final appointments = state.data ?? const <ExampleAppointment>[];
          final hasAppointments = appointments.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ActionsCard(
                repository: repository,
                onRefresh: () {
                  unawaited(controller.refetch());
                },
              ),
              const SizedBox(height: 12),
              if (state.isBackgroundFetching)
                const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
              if (!hasAppointments && state.hasData) const _EmptyPanel(),
              if (hasAppointments)
                for (final appointment in appointments)
                  Card(
                    child: ListTile(
                      title: Text(appointment.title),
                      subtitle: Text(
                        appointment.cancelled ? 'Cancelled' : 'Scheduled',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExampleDetailScreen(
                              appointment: appointment,
                              repository: repository,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              const SizedBox(height: 16),
              Text('Fetch count: ${repository.fetchCount}'),
            ],
          );
        },
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.repository, required this.onRefresh});

  final ExampleRepository repository;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onRefresh,
                  child: const Text('Refetch'),
                ),
                OutlinedButton(
                  onPressed: () {
                    repository.fetchReturnsEmptyOnce();
                    onRefresh();
                  },
                  child: const Text('Next empty'),
                ),
                OutlinedButton(
                  onPressed: () {
                    repository.fetchReturnsErrorOnce();
                    onRefresh();
                  },
                  child: const Text('Next error'),
                ),
                OutlinedButton(
                  onPressed: () {
                    repository.queueUpdatedData([
                      const ExampleAppointment('1', 'Design review updated'),
                      const ExampleAppointment('2', 'Team sync'),
                    ]);
                    onRefresh();
                  },
                  child: const Text('Stale reload'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the list item to open details, then press back to see cache-first rendering and focus refetch.',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No appointments found.')),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class ExampleDetailScreen extends StatelessWidget {
  const ExampleDetailScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });

  final ExampleAppointment appointment;
  final ExampleRepository repository;

  @override
  Widget build(BuildContext context) {
    final pilot = QueryPilotScope.of(context);
    final mutation = pilot.mutation<void, String>(
      mutationFn: repository.cancelAppointment,
      options: MutationOptions<void, String>(
        invalidateExactKeys: const [
          ['appointments'],
        ],
        optimisticUpdate: (pilot, id) {
          final previous = pilot
              .getQuery<List<ExampleAppointment>>(const ['appointments'])
              ?.state
              .data;
          pilot.updateQueryData<List<ExampleAppointment>>(
            const ['appointments'],
            (current) => [
              for (final item in current ?? const <ExampleAppointment>[])
                if (item.id == id) item.copyWith(cancelled: true) else item,
            ],
          );
          return () {
            pilot.updateQueryData<List<ExampleAppointment>>(const [
              'appointments',
            ], (_) => previous);
          };
        },
        onError: (pilot, error, stackTrace, variables) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment detail')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointment.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              appointment.cancelled ? 'Already cancelled' : 'Status: scheduled',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await mutation.execute(appointment.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Cancel with optimistic update'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                repository.failNextMutation();
                unawaited(mutation.execute(appointment.id));
              },
              child: const Text('Cancel and rollback'),
            ),
          ],
        ),
      ),
    );
  }
}
