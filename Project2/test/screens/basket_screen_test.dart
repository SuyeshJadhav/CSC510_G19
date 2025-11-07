// test/screens/basket_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:wolfbite/state/app_state.dart';
import 'package:wolfbite/screens/basket_screen.dart';

/// Test double that injects FakeFirestore and bypasses auth/persistence.
/// It still exercises the real business logic (caps, canAdd, etc.).
class TestAppState extends AppState {
  TestAppState() : super(db: FakeFirebaseFirestore());

  /// Allow manual UI refresh when we mutate fields directly.
  void tick() => notifyListeners();

  // --- Override mutations to remove _uid and Firestore persistence requirements.
  @override
  bool addItem({
    required String upc,
    required String name,
    required String category,
  }) {
    final cat = category.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    // Ensure category exists/capped like real code
    // (copy minimal bits from real helpers)
    Map<String, dynamic> ensure(String c) {
      if (!balances.containsKey(c)) {
        int? allowed;
        if (c.contains('CVB') ||
            c.contains('FRUIT') ||
            c.contains('VEGETABLE')) {
          allowed = null;
        } else if (c.contains('MILK') ||
            c.contains('CHEESE') ||
            c.contains('YOGURT') ||
            c.contains('DAIRY')) {
          allowed = 3;
        } else if (c.contains('BREAD') ||
            c.contains('GRAIN') ||
            c.contains('CEREAL')) {
          allowed = 2;
        } else if (c.contains('MEAT') ||
            c.contains('BEAN') ||
            c.contains('PEANUT')) {
          allowed = 1;
        } else if (c.contains('JUICE')) {
          allowed = 1;
        } else {
          allowed = 2;
        }
        balances[c] = {'allowed': allowed, 'used': 0};
      } else {
        balances[c]!.putIfAbsent('allowed', () => 2);
        balances[c]!.putIfAbsent('used', () => 0);
      }
      return balances[c]!;
    }

    final cap = ensure(cat);
    final allowed = cap['allowed'];
    final used = (cap['used'] ?? 0) as int;
    if (allowed is int && used >= allowed) return false;

    final idx = basket.indexWhere((e) => e['upc'] == upc && upc.isNotEmpty);
    if (idx >= 0) {
      incrementItem(upc);
      return false;
    }

    basket.add({'upc': upc, 'name': name, 'category': cat, 'qty': 1});
    balances[cat]!['used'] = used + 1;
    notifyListeners();
    return true;
  }

  @override
  void incrementItem(String upc) {
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;
    final cat = (basket[i]['category'] as String)
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase();
    final cap = balances[cat];
    if (cap != null) {
      final allowed = cap['allowed'];
      final used = (cap['used'] ?? 0) as int;
      if (allowed is int && used >= allowed) return;
      balances[cat]!['used'] = used + 1;
    }
    basket[i]['qty'] = (basket[i]['qty'] ?? 1) + 1;
    notifyListeners();
  }

  @override
  void decrementItem(String upc) {
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;
    final cat = (basket[i]['category'] as String)
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase();
    if (balances.containsKey(cat)) {
      final used = (balances[cat]!['used'] ?? 0) as int;
      balances[cat]!['used'] = (used - 1).clamp(0, 999);
    }
    final newQty = (basket[i]['qty'] ?? 1) - 1;
    if (newQty <= 0) {
      basket.removeAt(i);
    } else {
      basket[i]['qty'] = newQty;
    }
    notifyListeners();
  }
}

/// Minimal /scan stub so we can assert navigation.
class _ScanStub extends StatelessWidget {
  const _ScanStub();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Scan page')));
}

/// Build a testable app with Provider + GoRouter.
Widget _appWithRouter({
  required AppState app,
  String initialLocation = '/basket',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/basket', builder: (_, __) => const BasketScreen()),
      GoRoute(path: '/scan', builder: (_, __) => const _ScanStub()),
    ],
  );

  return ChangeNotifierProvider.value(
    value: app,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('BasketScreen', () {
    testWidgets('empty state + navigation to /scan', (tester) async {
      final app = TestAppState(); // empty basket
      await tester.pumpWidget(_appWithRouter(app: app));
      await tester.pumpAndSettle();

      expect(find.text('Your basket is empty'), findsOneWidget);
      expect(find.text('Scan products to add them here'), findsOneWidget);

      // Tap the CTA by text (robust against FilledButton internals)
      await tester.tap(find.text('Start Scanning'));
      await tester.pumpAndSettle();

      expect(find.text('Scan page'), findsOneWidget);
    });

    testWidgets('renders items and total badge', (tester) async {
      final app = TestAppState();
      // Two items: MILK x2, BREAD x1 => total 3
      app.addItem(upc: '111', name: 'Whole Milk Gallon', category: 'Milk');
      app.incrementItem('111');
      app.addItem(upc: '222', name: 'Brown Bread', category: 'Bread');

      await tester.pumpWidget(_appWithRouter(app: app));
      await tester.pumpAndSettle();

      // Header badge should show totalItems = 3
      expect(find.text('Total Items:'), findsOneWidget);
      expect(find.text('3'), findsWidgets); // badge and a qty "2" also appear

      // Item tiles present by names
      expect(find.text('Whole Milk Gallon'), findsOneWidget);
      expect(find.text('Brown Bread'), findsOneWidget);
    });

    testWidgets('increment and decrement update qty; remove at zero', (
      tester,
    ) async {
      final app = TestAppState();
      app.addItem(upc: '333', name: 'Yogurt Cups', category: 'Dairy'); // qty=1
      await tester.pumpWidget(_appWithRouter(app: app));
      await tester.pumpAndSettle();

      // Tap plus -> qty becomes 2
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('2'),
        findsWidgets,
      ); // one in avatar, one possibly in header badge

      // Tap minus twice -> remove item -> empty state
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your basket is empty'), findsOneWidget);
    });

    testWidgets('plus disabled when canAdd == false', (tester) async {
      final app = TestAppState();
      // Force category cap reached: allowed=1, used=1, qty=1
      app.balances['MILK'] = {'allowed': 1, 'used': 1};
      app.basket.add({
        'upc': '444',
        'name': '2% Milk',
        'category': 'MILK',
        'qty': 1,
      });
      app.tick();

      await tester.pumpWidget(_appWithRouter(app: app));
      await tester.pumpAndSettle();

      final plus = find.widgetWithIcon(IconButton, Icons.add_circle_outline);
      expect(plus, findsOneWidget);

      final plusBtn = tester.widget<IconButton>(plus);
      expect(plusBtn.onPressed, isNull); // disabled
    });

    testWidgets('tooltips exist for add/remove controls', (tester) async {
      final app = TestAppState();
      // canAdd true
      app.addItem(
        upc: '555',
        name: 'Oat Cereal',
        category: 'Cereal',
      ); // default allowed >= 2
      await tester.pumpWidget(_appWithRouter(app: app));
      await tester.pumpAndSettle();

      final minus = find.widgetWithIcon(
        IconButton,
        Icons.remove_circle_outline,
      );
      final plus = find.widgetWithIcon(IconButton, Icons.add_circle_outline);

      final minusBtn = tester.widget<IconButton>(minus);
      final plusBtn = tester.widget<IconButton>(plus);

      expect(minusBtn.tooltip, 'Remove one');
      expect(plusBtn.tooltip, 'Add one');

      // Now force limit and verify disabled tooltip
      app.balances['CEREAL'] = {'allowed': 1, 'used': 1};
      app.tick();
      await tester.pumpAndSettle();

      final plusBtnAfter = tester.widget<IconButton>(plus);
      expect(plusBtnAfter.onPressed, isNull);
      expect(plusBtnAfter.tooltip, 'Category limit reached');
    });

    testWidgets('long product names render without overflow', (tester) async {
      final app = TestAppState();
      const longName =
          'Very Very Very Long Product Name That Still Should Not Overflow The Tile';
      app.addItem(upc: '666', name: longName, category: 'Snacks');
      await tester.pumpWidget(_appWithRouter(app: app));
      await tester.pumpAndSettle();

      expect(find.text(longName), findsOneWidget);
    });
  });
}
