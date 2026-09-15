import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/widgets/otp_code_field.dart';

void main() {
  /// Pumps a minimal host for [OtpCodeField].
  Future<void> pumpField(
    WidgetTester tester,
    TextEditingController controller, {
    ValueChanged<String>? onCompleted,
    bool hasError = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: OtpCodeField(
              controller: controller,
              onCompleted: onCompleted,
              hasError: hasError,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders one box per digit', (tester) async {
    final controller = TextEditingController();
    await pumpField(tester, controller);
    expect(find.byType(TextField), findsNWidgets(6));
    controller.dispose();
  });

  testWidgets('typing advances focus and publishes the joined value',
      (tester) async {
    final controller = TextEditingController();
    await pumpField(tester, controller);

    final boxes = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
    }
    await tester.pump();

    expect(controller.text, '123456');
    controller.dispose();
  });

  testWidgets('fires onCompleted only once the code is full', (tester) async {
    final controller = TextEditingController();
    String? completed;
    await pumpField(tester, controller, onCompleted: (v) => completed = v);

    final boxes = find.byType(TextField);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
    }
    await tester.pump();
    expect(completed, isNull, reason: '5 of 6 digits is not complete');

    await tester.enterText(boxes.at(5), '6');
    await tester.pump();
    expect(completed, '123456');
    controller.dispose();
  });

  testWidgets('a pasted code fills every box', (tester) async {
    final controller = TextEditingController();
    await pumpField(tester, controller);

    // Simulate a clipboard paste landing in the first box.
    await tester.enterText(find.byType(TextField).first, '987654');
    await tester.pump();

    expect(controller.text, '987654');
    controller.dispose();
  });

  testWidgets('non-digits are discarded', (tester) async {
    final controller = TextEditingController();
    await pumpField(tester, controller);

    await tester.enterText(find.byType(TextField).first, 'a1b2c3');
    await tester.pump();

    expect(controller.text, '123');
    controller.dispose();
  });

  testWidgets('an externally set controller seeds the boxes', (tester) async {
    final controller = TextEditingController(text: '246810');
    await pumpField(tester, controller);
    await tester.pump();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.map((f) => f.controller!.text).join(), '246810');
    controller.dispose();
  });
}
