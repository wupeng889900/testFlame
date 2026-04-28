import 'package:flutter_test/flutter_test.dart';

import 'package:office_sim/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const OfficeGameApp());
    await tester.pump();

    expect(find.byType(OfficeGameApp), findsOneWidget);
  });

  testWidgets('office game page opens as the first screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OfficeGameApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });
}
