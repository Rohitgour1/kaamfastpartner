import 'package:flutter_test/flutter_test.dart';
import 'package:kaamfast_partner/main.dart';

void main() {
  testWidgets('Partner app boots to splash', (tester) async {
    await tester.pumpWidget(const KaamFastPartnerApp());
    expect(find.text('Kaam Fast Partner'), findsOneWidget);
    expect(find.text('Grow Your Work with Kaam Fast'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
