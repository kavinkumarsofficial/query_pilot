import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:query_pilot/query_pilot.dart';

class Appointment {
  const Appointment(this.id, this.title);

  final String id;
  final String title;
}

class AppointmentsRepo {
  AppointmentsRepo(this.seed);

  List<Appointment> seed;
  Completer<List<Appointment>>? nextList;
  int fetchCount = 0;

  Future<List<Appointment>> fetchAppointments() {
    fetchCount += 1;
    final pending = nextList;
    if (pending != null) {
      nextList = null;
      return pending.future;
    }
    return Future<List<Appointment>>.value(
      List<Appointment>.unmodifiable(seed),
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required QueryPilot pilot,
  required Widget home,
}) async {
  await tester.pumpWidget(
    QueryPilotScope(
      pilot: pilot,
      child: MaterialApp(navigatorObservers: [pilot.routeObserver], home: home),
    ),
  );
}

class AppointmentListScreen extends StatelessWidget {
  const AppointmentListScreen({super.key, required this.repo});

  final AppointmentsRepo repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QueryBuilder<List<Appointment>>(
        queryKey: const ['appointments'],
        queryFn: repo.fetchAppointments,
        options: const QueryOptions(
          staleTime: Duration(seconds: 1),
          cacheTime: Duration.zero,
        ),
        builder: (context, state, controller) {
          if (state.isInitialLoading && !state.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final appointments = state.data ?? const <Appointment>[];
          return ListView(
            children: [
              if (state.isBackgroundFetching)
                const LinearProgressIndicator(minHeight: 2),
              for (final appointment in appointments)
                ListTile(
                  title: Text(appointment.title),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AppointmentDetailsScreen(appointment: appointment),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class AppointmentDetailsScreen extends StatelessWidget {
  const AppointmentDetailsScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment details')),
      body: Center(child: Text('Appointment ${appointment.id}')),
    );
  }
}

void main() {
  testWidgets('keeps cached data visible and refetches on navigation focus', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 1, 1);
    final pilot = QueryPilot(now: () => now);
    final repo = AppointmentsRepo([
      const Appointment('1', 'Design review'),
      const Appointment('2', 'Weekly standup'),
    ]);

    await _pumpApp(
      tester,
      pilot: pilot,
      home: AppointmentListScreen(repo: repo),
    );

    await tester.pump();
    await tester.pump();
    expect(find.text('Design review'), findsOneWidget);
    expect(repo.fetchCount, 1);

    now = now.add(const Duration(seconds: 2));
    final refreshCompleter = Completer<List<Appointment>>();
    repo.nextList = refreshCompleter;

    await tester.tap(find.text('Design review'));
    await tester.pumpAndSettle();
    expect(repo.fetchCount, 1);

    await tester.pageBack();
    await tester.pump();

    expect(find.text('Design review'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(repo.fetchCount, 2);

    refreshCompleter.complete([
      const Appointment('1', 'Design review updated'),
      const Appointment('2', 'Weekly standup'),
    ]);
    await tester.pump();
    expect(find.text('Design review updated'), findsOneWidget);
  });

  testWidgets('refetches observed queries on app resume', (tester) async {
    var now = DateTime.utc(2026, 1, 1);
    final pilot = QueryPilot(now: () => now);
    final repo = AppointmentsRepo([const Appointment('1', 'Planning')]);

    await _pumpApp(
      tester,
      pilot: pilot,
      home: AppointmentListScreen(repo: repo),
    );

    await tester.pump();
    await tester.pump();
    expect(repo.fetchCount, 1);

    now = now.add(const Duration(seconds: 2));
    repo.nextList = Completer<List<Appointment>>();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.fetchCount, 2);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
