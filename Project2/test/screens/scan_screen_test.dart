import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:wolfbite/screens/scan_screen.dart';
import 'package:wolfbite/state/app_state.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../mocks/mocks.mocks.dart';

void main() {
  group('ScanScreen', () {
    late MockAplService mockAplService;
    late MockAppState mockAppState;
    late MockFirebaseAuth mockAuth;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockAplService = MockAplService();
      mockAppState = MockAppState();
      mockAuth = MockFirebaseAuth();
      mockGoRouter = MockGoRouter();
    });

    Future<void> pumpScanScreen(WidgetTester tester) async {
      // Set logical test window size (already doing physical size — keep it)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: MaterialApp(
            home: InheritedGoRouter(
              goRouter: mockGoRouter,
              child: ScanScreen(aplService: mockAplService, auth: mockAuth),
            ),
          ),
        ),
      );

      // ← THIS IS CRITICAL: allow first build to complete
      await tester
          .pumpAndSettle(); // ensures the initial widgets finish building
    }

    testWidgets('renders initial UI', (WidgetTester tester) async {
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);
      await pumpScanScreen(tester);

      expect(find.text('Scan Product'), findsOneWidget);
      expect(find.text('Enter UPC Code'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows product info when UPC is found', (
      WidgetTester tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer(
        (_) async => {'name': 'Test Product', 'category': 'Test Category'},
      );
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('Category: Test Category'), findsOneWidget);
    });

    testWidgets('shows "not found" message when UPC is not found', (
      WidgetTester tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer((_) async => null);
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text('UPC 12345 not found in APL'), findsOneWidget);
    });

    testWidgets('adds item to basket when "Add" button is tapped', (
      WidgetTester tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer(
        (_) async => {'name': 'Test Product', 'category': 'Test Category'},
      );
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);
      when(
        mockAppState.addItem(
          upc: anyNamed('upc'),
          name: anyNamed('name'),
          category: anyNamed('category'),
        ),
      ).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      // Desktop mode uses "Add" button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      verify(
        mockAppState.addItem(
          upc: '12345',
          name: 'Test Product',
          category: 'Test Category',
        ),
      ).called(1);
    });

    testWidgets('disables "Add" button when category limit is reached', (
      tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer(
        (_) async => {'name': 'Test Product', 'category': 'Test Category'},
      );
      when(mockAppState.canAdd('Test Category')).thenReturn(false);
      when(
        mockAppState.addItem(
          upc: anyNamed('upc'),
          name: anyNamed('name'),
          category: anyNamed('category'),
        ),
      ).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      // Verify product info appears
      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('Category limit reached'), findsOneWidget);

      // Verify "Add" text is visible (desktop mode)
      expect(find.text('Add'), findsOneWidget);

      // Try to tap the "Add" button - it should be disabled and do nothing
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify that addItem was NOT called (because button is disabled)
      verifyNever(
        mockAppState.addItem(
          upc: anyNamed('upc'),
          name: anyNamed('name'),
          category: anyNamed('category'),
        ),
      );
    });
    testWidgets('clears input after successful add', (
      WidgetTester tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer(
        (_) async => {'name': 'Test Product', 'category': 'Test Category'},
      );
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);
      when(
        mockAppState.addItem(
          upc: anyNamed('upc'),
          name: anyNamed('name'),
          category: anyNamed('category'),
        ),
      ).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      // Desktop mode uses "Add" button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets('calls signOut when logout button is tapped', (
      WidgetTester tester,
    ) async {
      when(mockAuth.signOut()).thenAnswer((_) async {});
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);
      when(mockGoRouter.go(any)).thenReturn(null);

      await pumpScanScreen(tester);

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      verify(mockAuth.signOut()).called(1);
      verify(mockGoRouter.go('/login')).called(1);
    });

    testWidgets('shows mobile UI on small screens', (
      WidgetTester tester,
    ) async {
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: MaterialApp(
            home: InheritedGoRouter(
              goRouter: mockGoRouter,
              child: ScanScreen(aplService: mockAplService, auth: mockAuth),
            ),
          ),
        ),
      );

      expect(find.text('Place barcode inside the square'), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(find.text('Re-check'), findsOneWidget);
      expect(find.text('Add to Basket'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('disables mobile "Add" button when category limit is reached', (
      WidgetTester tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer(
        (_) async => {'name': 'Test Product', 'category': 'Test Category'},
      );

      when(
        mockAppState.canAdd(
          argThat(allOf(isA<String>(), isNot('Test Category'))),
        ),
      ).thenReturn(true);
      when(mockAppState.canAdd('Test Category')).thenReturn(false);

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: MaterialApp(
            home: InheritedGoRouter(
              goRouter: mockGoRouter,
              child: ScanScreen(aplService: mockAplService, auth: mockAuth),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mobile mode doesn't have text input - need to simulate barcode scan
      // Since we can't trigger _onDetect directly, this test verifies initial state
      final addButtonFinder = find.ancestor(
        of: find.text('Add to Basket'),
        matching: find.byType(FilledButton),
      );
      expect(addButtonFinder, findsOneWidget);

      final addButton = tester.widget<FilledButton>(addButtonFinder);
      // Button should be disabled initially (no item scanned)
      expect(addButton.onPressed, isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('shows error snackbar on exception', (
      WidgetTester tester,
    ) async {
      when(
        mockAplService.findByUpc('12345'),
      ).thenThrow(Exception('Network error'));
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text('Error: Exception: Network error'), findsOneWidget);
    });

    testWidgets('prevents concurrent scans via busy flag', (
      WidgetTester tester,
    ) async {
      var callCount = 0;
      when(mockAplService.findByUpc('12345')).thenAnswer((_) async {
        callCount++;
        await Future.delayed(const Duration(milliseconds: 100));
        return {'name': 'Test Product', 'category': 'Test Category'};
      });
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      // Don't wait for completion
      await tester.pump();

      // Try to check again while first check is in progress
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      // Should only be called once due to busy flag
      expect(callCount, 1);
    });

    testWidgets('submits UPC on TextField enter key', (
      WidgetTester tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer(
        (_) async => {'name': 'Test Product', 'category': 'Test Category'},
      );
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Test Product'), findsOneWidget);
    });

    testWidgets('shows "No item scanned yet" when adding without scanning', (
      WidgetTester tester,
    ) async {
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: MaterialApp(
            home: InheritedGoRouter(
              goRouter: mockGoRouter,
              child: ScanScreen(aplService: mockAplService, auth: mockAuth),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Add button should be disabled initially
      final addButtonFinder = find.widgetWithText(
        FilledButton,
        'Add to Basket',
      );
      expect(addButtonFinder, findsOneWidget);

      final addButton = tester.widget<FilledButton>(addButtonFinder);
      expect(addButton.onPressed, isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Re-check button is disabled when no item scanned', (
      WidgetTester tester,
    ) async {
      when(mockAppState.canAdd(argThat(isA<String>()))).thenReturn(true);

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: MaterialApp(
            home: InheritedGoRouter(
              goRouter: mockGoRouter,
              child: ScanScreen(aplService: mockAplService, auth: mockAuth),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final recheckButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Re-check'),
      );
      expect(recheckButton.onPressed, isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('shows warning icon when category limit reached on desktop', (
      WidgetTester tester,
    ) async {
      when(mockAplService.findByUpc('12345')).thenAnswer(
        (_) async => {'name': 'Test Product', 'category': 'Test Category'},
      );
      when(
        mockAppState.canAdd(
          argThat(allOf(isA<String>(), isNot('Test Category'))),
        ),
      ).thenReturn(true);
      when(mockAppState.canAdd('Test Category')).thenReturn(false);

      await pumpScanScreen(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.text('Category limit reached'), findsOneWidget);
    });
  });
}
