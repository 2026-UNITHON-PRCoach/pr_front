import 'package:flutter_test/flutter_test.dart';
import 'package:pr_front/main.dart';

void main() {
  testWidgets(
    '홈 화면이 정상적으로 표시된다',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const PresentationCoachApp(),
      );

      expect(
        find.text('Speechinx'),
        findsOneWidget,
      );

      expect(
        find.text('음성만'),
        findsOneWidget,
      );

      expect(
        find.text('파일 업로드'),
        findsOneWidget,
      );
    },
  );
}
