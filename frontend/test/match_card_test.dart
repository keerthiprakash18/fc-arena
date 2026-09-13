import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/models/match.dart';
import 'package:fc_arena/widgets/match_card.dart';

/// Widget tests for the fixture card.
///
/// These matter because the card is purely visual: a regression here shows up
/// as a blank or wrong-looking card rather than a thrown exception, so the
/// important cases are pinned down explicitly.
Match _match({
  String status = 'SCHEDULED',
  int? homeScore,
  int? awayScore,
  String? scheduledAt,
  String? roundName,
  String venue = '',
}) {
  return Match(
    id: 1,
    leagueId: 1,
    homeTeamName: 'Nova Stars',
    awayTeamName: 'Thunder FC',
    homeTeamShortName: 'Nova Stars',
    awayTeamShortName: 'Thunder FC',
    homeDisplay: 'Nova Stars',
    awayDisplay: 'Thunder FC',
    isTeamMatch: true,
    roundName: roundName,
    venue: venue,
    homeScore: homeScore,
    awayScore: awayScore,
    status: status,
    scheduledAt: scheduledAt,
    createdAt: '2026-09-01T00:00:00Z',
  );
}

/// Pumps the card and lets its entry animation finish.
///
/// Deliberately not `pumpAndSettle`: the live badge pulses forever, so a
/// settling pump would time out on any in-progress fixture.
Future<void> _pump(
  WidgetTester tester,
  Match match, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: SingleChildScrollView(child: MatchCard(match: match)),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('an unplayed fixture shows both sides and a VS marker',
      (tester) async {
    await _pump(tester, _match(roundName: 'League Round'));

    expect(find.text('Nova Stars'), findsOneWidget);
    expect(find.text('Thunder FC'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('LEAGUE ROUND'), findsOneWidget);
  });

  testWidgets('a played fixture shows the score instead of VS', (tester) async {
    await _pump(tester, _match(status: 'VERIFIED', homeScore: 3, awayScore: 1));

    expect(find.text('VS'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
  });

  testWidgets('an upcoming fixture with a kick-off time shows a countdown',
      (tester) async {
    final kickoff = DateTime.now()
        .add(const Duration(hours: 5, minutes: 30))
        .toUtc()
        .toIso8601String();
    await _pump(tester, _match(scheduledAt: kickoff));

    // Countdown text is of the form "in 5h 29m"; assert on the stable prefix.
    expect(find.textContaining('in '), findsOneWidget);
  });

  testWidgets('a fixture with no kick-off time shows no countdown',
      (tester) async {
    await _pump(tester, _match(scheduledAt: null));

    expect(find.textContaining('in '), findsNothing);
  });

  testWidgets('a scheduled fixture does not claim to be live', (tester) async {
    await _pump(tester, _match());
    expect(find.text('LIVE'), findsNothing);
  });

  testWidgets('an in-progress fixture is badged live', (tester) async {
    await _pump(tester, _match(status: 'IN_PROGRESS', homeScore: 2, awayScore: 1));
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('venue is shown when the fixture has one', (tester) async {
    await _pump(tester, _match(venue: 'Room A'));
    expect(find.textContaining('Room A'), findsOneWidget);
  });

  testWidgets('compact mode drops the round header', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MatchCard(
            match: _match(roundName: 'League Round'),
            compact: true,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('LEAGUE ROUND'), findsNothing);
    // The fixture itself is still readable.
    expect(find.text('Nova Stars'), findsOneWidget);
  });

  testWidgets('reduce-motion still renders the full card', (tester) async {
    await _pump(
      tester,
      _match(status: 'VERIFIED', homeScore: 3, awayScore: 1),
      reduceMotion: true,
    );

    expect(find.text('Nova Stars'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
  });

  testWidgets('a fixture with no round falls back to a neutral label',
      (tester) async {
    await _pump(tester, _match(roundName: null));
    expect(find.text('TEAM FIXTURE'), findsOneWidget);
  });
}
