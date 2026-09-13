import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/widgets/responsive.dart';

/// The grid decides how many columns fit and then divides the remaining width
/// between them. Getting that arithmetic wrong produces layouts that look
/// almost right, so the numbers are pinned here.
///
/// The window itself is resized rather than wrapping the grid in a SizedBox:
/// the default test surface is only 800px wide, which would clamp anything
/// wider and quietly invalidate the arithmetic under test.
Future<void> _pumpGrid(
  WidgetTester tester, {
  required double width,
  int count = 4,
  double minItemWidth = 400,
  int maxColumns = 3,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AdaptiveGrid(
        minItemWidth: minItemWidth,
        maxColumns: maxColumns,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(key: ValueKey(i), height: 50, child: Text('$i')),
        ],
      ),
    ),
  ));
}

void main() {
  testWidgets('a narrow width falls back to a single full-width column',
      (tester) async {
    await _pumpGrid(tester, width: 380);

    final size = tester.getSize(find.byKey(const ValueKey(0)));
    expect(size.width, 380, reason: 'one column uses the whole width');
  });

  testWidgets('two columns fit when the width allows it', (tester) async {
    await _pumpGrid(tester, width: 900);

    final first = tester.getSize(find.byKey(const ValueKey(0)));
    final second = tester.getSize(find.byKey(const ValueKey(1)));

    // (900 - 12 spacing) / 2 = 444
    expect(first.width, closeTo(444, 0.5));
    expect(second.width, closeTo(444, 0.5));
    // The second item must sit beside the first, not below it.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(1))).dy,
      tester.getTopLeft(find.byKey(const ValueKey(0))).dy,
    );
  });

  testWidgets('columns are capped so cards never get too narrow', (tester) async {
    // 2000 / 400 would allow 5 columns, but maxColumns is 3.
    await _pumpGrid(tester, width: 2000, maxColumns: 3);

    final first = tester.getSize(find.byKey(const ValueKey(0)));
    // (2000 - 12 * 2) / 3 = 658.67
    expect(first.width, closeTo(658.67, 0.5));

    // Items 3 and 4 wrap onto a second row.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(3))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey(0))).dy),
    );
  });

  testWidgets('an empty grid renders nothing rather than throwing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AdaptiveGrid(children: [])),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('ContentWidth caps the measure on a wide window', (tester) async {
    tester.view.physicalSize = const Size(2400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ContentWidth(
          maxWidth: 1000,
          // Must ask for infinite width, otherwise it collapses to zero and the
          // test would pass for the wrong reason.
          child: SizedBox(
            key: ValueKey('inner'),
            width: double.infinity,
            height: 20,
          ),
        ),
      ),
    ));

    // The child is bounded by maxWidth, not by the 2400px window.
    expect(tester.getSize(find.byKey(const ValueKey('inner'))).width, 1000);
  });

  testWidgets('form factor follows the window width', (tester) async {
    Future<FormFactor> at(double width) async {
      late FormFactor result;
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          result = formFactorOf(context);
          return const SizedBox.shrink();
        }),
      ));
      return result;
    }

    expect(await at(400), FormFactor.mobile);
    expect(await at(800), FormFactor.tablet);
    expect(await at(1400), FormFactor.desktop);
  });

  testWidgets('isMobile matches the mobile form factor', (tester) async {
    tester.view.physicalSize = const Size(380, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late bool mobile;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        mobile = isMobile(context);
        return const SizedBox.shrink();
      }),
    ));
    expect(mobile, isTrue);
  });
}
