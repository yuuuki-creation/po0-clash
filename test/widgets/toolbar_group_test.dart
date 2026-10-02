import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  for (final (density, extent) in [
    (VisualDensity.standard, 40.0),
    (VisualDensity.compact, 32.0),
  ]) {
    testWidgets('mixed toolbar buttons line up at $extent px', (tester) async {
      await tester.pumpWidget(
        TestApp(
          includeNavigatorKey: false,
          child: Theme(
            data: ThemeData(visualDensity: density),
            child: CommonScaffold(
              title: 'title',
              body: const SizedBox(),
              actions: [
                FilledButton.tonal(onPressed: () {}, child: const Text('OK')),
                IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
              ],
            ),
          ),
        ),
      );

      final filled = tester.getRect(find.byType(FilledButton));
      final icon = tester.getRect(find.byType(IconButton));
      expect(filled.height, extent);
      expect(icon.size, Size.square(extent));
      expect(filled.center.dy, icon.center.dy);
      expect(icon.left - filled.right, 4);
      expect(tester.takeException(), isNull);
    });
  }
}
