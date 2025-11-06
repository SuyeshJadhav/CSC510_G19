import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:wolfbite/screens/login_screen.dart';

// Import the generated mocks
import '../mocks/mocks.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockGoRouter mockGoRouter;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockGoRouter = MockGoRouter();
  });

  Widget createWidgetWithMocks() {
    return MaterialApp(
      home: InheritedGoRouter(
        goRouter: mockGoRouter,
        child: LoginScreen(auth: mockAuth),
      ),
    );
  }

  group('LoginScreen UI and Validation', () {
    testWidgets('displays all required UI elements', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const LoginScreen()));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('password field is obscured by default', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const LoginScreen()));
      final passwordField = tester.widget<TextField>(
        find.byType(TextField).last,
      );
      expect(passwordField.obscureText, true);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const LoginScreen()));
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('email field has correct keyboard type', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const LoginScreen()));
      final emailField = tester.widget<TextField>(find.byType(TextField).first);
      expect(emailField.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('validates invalid email format', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).first, 'notanemail');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email'), findsOneWidget);
    });

    testWidgets('validates short password', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, '123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Min 6 chars'), findsOneWidget);
    });

    // --- NEW TEST FOR 100% COVERAGE ---
    testWidgets('When "Create account" is tapped, Then navigates to /signup', (
      tester,
    ) async {
      // 1. Build the widget with mocks
      await tester.pumpWidget(createWidgetWithMocks());

      // 2. Find and tap the button
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      // 3. Verify navigation
      verify(mockGoRouter.go('/signup')).called(1);
    });
  });

  // --- Group 2: Tests for Login Logic ---
  group('LoginScreen Submission Logic', () {
    testWidgets(
      'Given valid credentials, When Sign In is tapped, Then calls Firebase and navigates to /scan',
      (tester) async {
        when(
          mockAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenAnswer((_) async => MockUserCredential());

        await tester.pumpWidget(createWidgetWithMocks());

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'test@test.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        verify(
          mockAuth.signInWithEmailAndPassword(
            email: 'test@test.com',
            password: 'password123',
          ),
        ).called(1);
        verify(mockGoRouter.go('/scan')).called(1);
      },
    );

    // --- NEW TEST FOR 100% COVERAGE ---
    testWidgets(
      'Given valid credentials, When form is submitted via keyboard, Then calls Firebase and navigates',
      (tester) async {
        // 1. Stub the mockAuth call to succeed
        when(
          mockAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenAnswer((_) async => MockUserCredential());

        // 2. Build the widget
        await tester.pumpWidget(createWidgetWithMocks());

        // 3. Enter valid text
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'test@test.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');

        // 4. Simulate pressing "done" on the keyboard
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // 5. Verify Firebase was called
        verify(
          mockAuth.signInWithEmailAndPassword(
            email: 'test@test.com',
            password: 'password123',
          ),
        ).called(1);

        // 6. Verify we navigated
        verify(mockGoRouter.go('/scan')).called(1);
      },
    );

    testWidgets(
      'Given invalid credentials, When Sign In fails, Then shows a SnackBar',
      (tester) async {
        when(
          mockAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(
          FirebaseAuthException(
            code: 'wrong-password',
            message: 'Invalid password',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ScaffoldMessenger(
              child: InheritedGoRouter(
                goRouter: mockGoRouter,
                child: LoginScreen(auth: mockAuth),
              ),
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'test@test.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Invalid password'), findsOneWidget);
        verifyNever(mockGoRouter.go(any));
      },
    );

    testWidgets('Shows loading indicator when signing in', (tester) async {
      when(
        mockAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenAnswer((_) {
        // Create a Future that never finishes
        return Completer<UserCredential>().future;
      });

      await tester.pumpWidget(createWidgetWithMocks());

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));

      // Pump one frame to show the loading state
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    });
  });
}
