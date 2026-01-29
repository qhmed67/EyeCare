import 'package:flutter_test/flutter_test.dart';
import 'package:eyecare/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const EyeCareApp(initialRoute: '/'));
    expect(find.textContaining('Smart'), findsWidgets);
  });
}
