import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/app/di/service_locator.dart';
import 'package:invo_print/app/invo_print_app.dart';

void main() {
  setUpAll(setupServiceLocator);

  testWidgets('renders InvoPrint login screen', (tester) async {
    await tester.pumpWidget(const InvoPrintApp());
    await tester.pump();

    expect(find.text('InvoPrint'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
