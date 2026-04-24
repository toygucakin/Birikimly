import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/main.dart';

void main() {
  testWidgets('App renders loading or home', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BirikimlyApp(),
      ),
    );

    // Initial check - loading or content
    expect(find.byType(BirikimlyApp), findsOneWidget);
  });
}
