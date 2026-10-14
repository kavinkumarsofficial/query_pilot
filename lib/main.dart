import 'dart:async';

import 'package:flutter/material.dart';
import 'package:query_pilot/query_pilot.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final QueryPilot _pilot = QueryPilot();
  final _repository = DemoRepository();

  @override
  Widget build(BuildContext context) {
    return QueryPilotScope(
      pilot: _pilot,
      child: MaterialApp(
        title: 'QueryPilot',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        navigatorObservers: [_pilot.routeObserver],
        home: AppointmentListScreen(repository: _repository),
      ),
    );
  }
}

class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.time,
    this.cancelled = false,
  });

  final String id;
  final String title;
  final DateTime time;
  final bool cancelled;

  Appointment copyWith({bool? cancelled}) {
    return Appointment(
      id: id,
      title: title,
      time: time,
      cancelled: cancelled ?? this.cancelled,
    );
  }
}

class DemoRepository {
  DemoRepository() {
    _items = <Appointment>[
      Appointment(
        id: 'a1',
        title: 'Weekly planning',
        time: DateTime.now().add(const Duration(hours: 2)),
      ),
      Appointment(
        id: 'a2',
        title: 'Client check-in',
        time: DateTime.now().add(const Duration(hours: 4)),
      ),
    ];
  }

  late List<Appointment> _items;
  Completer<List<Appointment>>? _pendingReload;

  Future<List<Appointment>> fetchAppointments() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final pending = _pendingReload;
    if (pending != null) {
      _pendingReload = null;
      return pending.future;
    }
    return List<Appointment>.unmodifiable(_items);
  }

  void queueNextReload(List<Appointment> items) {
    _pendingReload = Completer<List<Appointment>>();
    Future<void>.microtask(() => _pendingReload?.complete(items));
  }

  Future<void> cancelAppointment(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _items = _items
        .map((appointment) {
          if (appointment.id == id) {
            return appointment.copyWith(cancelled: true);
          }
          return appointment;
        })
        .toList(growable: false);
  }
}

class AppointmentListScreen extends StatelessWidget {
  const AppointmentListScreen({super.key, required this.repository});

  final DemoRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: QueryBuilder<List<Appointment>>(
        queryKey: const ['appointments'],
        queryFn: repository.fetchAppointments,
        options: const QueryOptions(
          staleTime: Duration(seconds: 20),
          refetchOnFocus: true,
          refetchOnResume: true,
        ),
        builder: (context, state, controller) {
          if (state.isInitialLoading && !state.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.isInitialError && !state.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${state.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: controller.retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final appointments = state.data ?? const <Appointment>[];
          return RefreshIndicator(
            onRefresh: () async {
              await controller.refetch();
            },
            child: ListView(
              children: [
                if (state.isBackgroundFetching)
                  const LinearProgressIndicator(minHeight: 2),
                for (final appointment in appointments)
                  ListTile(
                    title: Text(appointment.title),
                    subtitle: Text(
                      appointment.cancelled
                          ? 'Cancelled'
                          : appointment.time.toLocal().toString(),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AppointmentDetailsScreen(
                            appointment: appointment,
                            repository: repository,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () {
                    unawaited(controller.refetch());
                  },
                  child: const Text('Manual refresh'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AppointmentDetailsScreen extends StatelessWidget {
  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });

  final Appointment appointment;
  final DemoRepository repository;

  @override
  Widget build(BuildContext context) {
    final pilot = QueryPilotScope.of(context);

    final cancelMutation = pilot.mutation<void, String>(
      mutationFn: repository.cancelAppointment,
      options: MutationOptions<void, String>(
        invalidateExactKeys: const [
          ['appointments'],
        ],
        optimisticUpdate: (pilot, id) {
          final previous = pilot
              .getQuery<List<Appointment>>(const ['appointments'])
              ?.state
              .data;
          pilot.updateQueryData<List<Appointment>>(
            const ['appointments'],
            (current) => [
              for (final item in current ?? const <Appointment>[])
                if (item.id == id) item.copyWith(cancelled: true) else item,
            ],
          );
          return () {
            pilot.updateQueryData<List<Appointment>>(const [
              'appointments',
            ], (_) => previous);
          };
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(appointment.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointment ${appointment.id}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              appointment.cancelled ? 'Already cancelled' : 'Status: scheduled',
            ),
            const Spacer(),
            FilledButton(
              onPressed: appointment.cancelled
                  ? null
                  : () async {
                      await cancelMutation.execute(appointment.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Cancel appointment'),
            ),
          ],
        ),
      ),
    );
  }
}
