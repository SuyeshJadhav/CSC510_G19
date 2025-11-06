import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mockito/mockito.dart';
import 'package:wolfbite/screens/signup_page.dart';

// Import the generated mocks
import '../mocks/mocks.mocks.dart';

void main() {
  // --- Setup Mocks ---
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockGoRouter mockGoRouter;

  // Mocks for the "chain" of calls
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  // --- FIX: Add <Map<String, dynamic>> to these two lines ---
  late MockCollectionReference<Map<String, dynamic>> mockCollectionRef;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;

  setUp(() {
    // 1. Create top-level mocks
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockGoRouter = MockGoRouter();

    // 2. Create chained mocks
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    // --- FIX: Add <Map<String, dynamic>> to these two lines ---
    mockCollectionRef = MockCollectionReference<Map<String, dynamic>>();
    mockDocRef = MockDocumentReference<Map<String, dynamic>>();

    // 3. Stub the mock chains
    // Auth chain: auth.createUser... -> credential.user -> uid
    when(mockUser.uid).thenReturn('mock-uid-123');
    when(mockUserCredential.user).thenReturn(mockUser);
    when(
      mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ),
    ).thenAnswer((_) async => mockUserCredential);

    // Auth chain for signOut()
    when(mockAuth.signOut()).thenAnswer((_) async {});

    // Firestore chain: firestore.collection().doc().set()
    // --- These lines will now work correctly ---
    when(mockFirestore.collection('users')).thenReturn(mockCollectionRef);
    when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
    when(mockDocRef.set(any)).thenAnswer((_) async {});
  });

  // Helper function to build the widget with all mocks
  Widget createWidgetWithMocks() {
    return MaterialApp(
      home: InheritedGoRouter(
        goRouter: mockGoRouter,
        child: SignupPage(auth: mockAuth, firestore: mockFirestore),
      ),
    );
  }

  // Helper to fill the form with valid data
  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), '123 Main St');
  }

  // --- Group 1: UI and Validation Tests ---
  group('SignupPage UI and Validation', () {
    testWidgets('displays all required UI elements', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const SignupPage()));
      expect(find.text('Let’s get you started'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password (min 6 chars)'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Already have an account? Log in'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(MaterialApp(home: const SignupPage()));
      // Find the password field's underlying text field
      final passwordTextField = tester.widget<TextField>(
        find.byType(TextField).at(2),
      );
      expect(passwordTextField.obscureText, true);

      // Tap the toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Check again
      final updatedPasswordField = tester.widget<TextField>(
        find.byType(TextField).at(2),
      );
      expect(updatedPasswordField.obscureText, false);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('validates all empty fields', (tester) async {
      await tester.pumpWidget(createWidgetWithMocks());
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Check all validation messages from your code
      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(find.text('Enter your address'), findsOneWidget);
    });
  });

  // --- Group 2: Navigation ---
  group('SignupPage Navigation', () {
    testWidgets('tapping "Log in" navigates to /login', (tester) async {
      await tester.pumpWidget(createWidgetWithMocks());
      await tester.tap(find.text('Already have an account? Log in'));
      await tester.pumpAndSettle();
      verify(mockGoRouter.go('/login')).called(1);
    });
  });

  // --- Group 3: Submission Logic ---
  group('SignupPage Submission Logic', () {
    testWidgets(
      'Given valid form, When Sign Up is tapped, Then creates user, saves profile, signs out, and navigates to /login',
      (tester) async {
        await tester.pumpWidget(createWidgetWithMocks());
        await fillValidForm(tester);

        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();

        // 1. Verify Auth was called
        verify(
          mockAuth.createUserWithEmailAndPassword(
            email: 'test@test.com',
            password: 'password123',
          ),
        ).called(1);

        // 2. Verify Firestore was called with the correct UID and data
        verify(mockCollectionRef.doc('mock-uid-123')).called(1);
        verify(
          mockDocRef.set(
            argThat(
              isA<Map<String, dynamic>>()
                  .having((map) => map['name'], 'name', 'Test User')
                  .having((map) => map['email'], 'email', 'test@test.com')
                  .having((map) => map['address'], 'address', '123 Main St'),
            ),
          ),
        ).called(1);

        // 3. --- VERIFY YOUR LOGIC ---
        // We check that signOut() was called
        verify(mockAuth.signOut()).called(1);

        // 4. --- VERIFY YOUR LOGIC ---
        // We check that it navigated to /login
        verify(mockGoRouter.go('/login')).called(1);
      },
    );

    testWidgets(
      'Given auth fails, When Sign Up is tapped, Then shows SnackBar and does NOT save profile',
      (tester) async {
        // 1. Stub Auth to throw an error
        when(
          mockAuth.createUserWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(
          FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email already in use',
          ),
        );

        // 2. Build widget (need ScaffoldMessenger for SnackBar)
        await tester.pumpWidget(
          MaterialApp(
            home: ScaffoldMessenger(
              child: InheritedGoRouter(
                goRouter: mockGoRouter,
                child: SignupPage(auth: mockAuth, firestore: mockFirestore),
              ),
            ),
          ),
        );

        // 3. Fill form and tap
        await fillValidForm(tester);
        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();

        // 4. Verify Auth was called
        verify(
          mockAuth.createUserWithEmailAndPassword(
            email: 'test@test.com',
            password: 'password123',
          ),
        ).called(1);

        // 5. Verify Firestore was NEVER called
        verifyNever(mockFirestore.collection('users'));
        verifyNever(mockDocRef.set(any));

        // 6. Verify SnackBar is shown
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Email already in use'), findsOneWidget);

        // 7. Verify signOut() was NOT called
        verifyNever(mockAuth.signOut());
        verifyNever(mockGoRouter.go('/login'));
      },
    );

    testWidgets('Shows loading indicator when signing up', (tester) async {
      // 1. Stub Auth to hang (never complete)
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          // v-- THIS IS THE FIX --v
          password: anyNamed('password'),
        ),
      ).thenAnswer((_) => Completer<UserCredential>().future);

      // 2. Build widget and fill form
      await tester.pumpWidget(createWidgetWithMocks());
      await fillValidForm(tester);

      // 3. Tap "Sign Up" and pump one frame
      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      // 4. Verify loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign Up'), findsNothing);
    });
  });
}
