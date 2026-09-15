import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fc_arena/main.dart';
import 'package:fc_arena/screens/splash_screen.dart';
import 'package:fc_arena/screens/onboarding_screen.dart';

/// Let the splash timer fire and its 600 ms cross-fade finish.
///
/// The splash replaces itself with a 600 ms [PageRouteBuilder] transition, and
/// the outgoing route stays mounted until that transition completes. Pumping
/// exactly 600 ms lands on the boundary frame, so we overshoot deliberately —
/// `pumpAndSettle` is not an option because the splash's indeterminate progress
/// spinner never settles.
Future<void> _settleSplash(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3)); // splash delay elapses
  await tester.pump(); // SharedPreferences read + navigation
  await tester.pump(const Duration(milliseconds: 900)); // cross-fade completes
}

void main() {
  testWidgets('App boots to splash, then first-run onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FCArenaApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await _settleSplash(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('Returning user skips onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(const FCArenaApp());
    await _settleSplash(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}