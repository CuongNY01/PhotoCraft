import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('PhotoCraft basic test', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoCraftApp());
    expect(find.text('Trang chủ'), findsWidgets);
  });
}
