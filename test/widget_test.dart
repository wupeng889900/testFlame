import 'package:flutter_test/flutter_test.dart';

import 'package:office_sim/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets('office game page opens', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('进入 Office Game'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });
}
