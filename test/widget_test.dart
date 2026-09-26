import 'package:flutter_test/flutter_test.dart';
import 'package:circuit_point/main.dart';

void main() {
  testWidgets('App should render login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(isLoggedIn: false));

    // Verify that the title is present.
    expect(find.text('Login to continue'), findsOneWidget);
  });
}
