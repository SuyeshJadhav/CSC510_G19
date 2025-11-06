import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:wolfbite/screens/balances_screen.dart';
import 'package:wolfbite/state/app_state.dart';
import 'package:go_router/go_router.dart';

import '../mocks/mocks.mocks.dart';

void main() {
  group('BalancesScreen', () {
    late MockAppState mockAppState;
    late MockGoRouter mockGoRouter;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      mockAppState = MockAppState();
      mockGoRouter = MockGoRouter();
      mockAuth = MockFirebaseAuth();
    });

    Future<void> pumpBalancesScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: MaterialApp(
            home: InheritedGoRouter(
              goRouter: mockGoRouter,
              child: BalancesScreen(auth: mockAuth),
            ),
          ),
        ),
      );
    }

    testWidgets('renders loading indicator when balances are not loaded', (
      WidgetTester tester,
    ) async {
      when(mockAppState.balancesLoaded).thenReturn(false);
      when(mockAppState.balances).thenReturn({});

      await pumpBalancesScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when balances are loaded but empty', (
      WidgetTester tester,
    ) async {
      when(mockAppState.balancesLoaded).thenReturn(true);
      when(mockAppState.balances).thenReturn({});

      await pumpBalancesScreen(tester);

      expect(find.text('No benefit data yet'), findsOneWidget);
    });

    testWidgets('renders a list of balances when loaded', (
      WidgetTester tester,
    ) async {
      when(mockAppState.balancesLoaded).thenReturn(true);
      when(mockAppState.balances).thenReturn({
        'MILK': {'allowed': 3, 'used': 1},
        'FRUITS': {'allowed': null, 'used': 5},
      });

      await pumpBalancesScreen(tester);

      expect(find.text('MILK'), findsOneWidget);
      expect(find.text('Used: 1 of 3 items'), findsOneWidget);
      expect(find.text('FRUITS'), findsOneWidget);
      expect(find.text('Used: 5 items'), findsOneWidget);
      expect(find.text('Unlimited'), findsOneWidget);
    });

    testWidgets('calls signOut when logout button is tapped', (
      WidgetTester tester,
    ) async {
      when(mockAppState.balancesLoaded).thenReturn(true);
      when(mockAppState.balances).thenReturn({});
      when(mockAuth.signOut()).thenAnswer((_) async {});
      when(mockGoRouter.go(any)).thenReturn(null);

      await pumpBalancesScreen(tester);

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      verify(mockAuth.signOut()).called(1);
      verify(mockGoRouter.go('/login')).called(1);
    });
  });
}
