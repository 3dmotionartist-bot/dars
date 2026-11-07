import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_tutor_app/main.dart';
import 'package:my_tutor_app/state/app_state.dart';

void main() {
  testWidgets('Welcome screen renders', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => AppState(), child: const DarsApp()));
    await tester.pump();
    expect(find.text('من سيستخدم التطبيق؟'), findsOneWidget);
  });
}
