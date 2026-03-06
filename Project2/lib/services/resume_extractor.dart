import '../models/abcd_report.dart';

/// Service for extracting resume-ready facts from this codebase using the
/// ABCD framework (Action, Benefit, Context, Data).
///
/// Reports ONLY directly verifiable facts from the source code — no
/// embellishment or inference beyond what the code itself shows. Metrics
/// that cannot be confirmed from code are flagged with `[NEEDS METRIC]`.
///
/// Usage:
/// ```dart
/// final extractor = ResumeExtractorService();
/// for (final report in extractor.extractAll()) {
///   print(report.toFormattedString());
/// }
/// ```
class ResumeExtractorService {
  const ResumeExtractorService();

  /// Returns ABCD framework reports for every project in this repository.
  ///
  /// Currently contains one project: WolfBite (Smart WIC Cart).
  List<AbcdReport> extractAll() => [wolfbiteReport()];

  /// Extracts ABCD resume framework data for the WolfBite project.
  ///
  /// WolfBite is a Flutter application that helps WIC (Women, Infants, and
  /// Children) program participants manage their benefit purchases by
  /// scanning product barcodes and tracking per-category allowances.
  ///
  /// All facts are taken directly from source in `Project2/`.
  AbcdReport wolfbiteReport() {
    return const AbcdReport(
      projectName: 'WolfBite — Smart WIC Cart (Flutter / Firebase)',

      // ------------------------------------------------------------------ //
      // A — ACTION                                                           //
      // ------------------------------------------------------------------ //
      actionsFound: [
        'Implements live camera barcode scanning via the MobileScanner widget',
        'Queries Cloud Firestore APL collection for WIC product eligibility '
            'by UPC document ID',
        'Manages a shopping basket with add, increment, and decrement '
            'item operations via AppState',
        'Persists basket and balance data to Cloud Firestore using set() '
            'with merge:true and a server timestamp',
        'Canonicalises category strings by trimming whitespace, collapsing '
            'multiple spaces, and converting to uppercase',
        'Derives default per-category WIC item caps by keyword matching '
            'on the canonical category name',
        'Enforces per-category WIC item limits in canAdd() before any '
            'basket mutation is allowed',
        'Authenticates users via Firebase Auth email/password '
            'signInWithEmailAndPassword',
        'Guards application routes with a GoRouter redirect callback '
            'driven by FirebaseAuth.instance.currentUser',
        'Converts FirebaseAuth.authStateChanges() stream into a '
            'ChangeNotifier (GoRouterRefreshStream) for automatic '
            'GoRouter re-evaluation',
        'Renders a colour-coded LinearProgressIndicator for each WIC '
            'benefit category to visualise usage',
        'Handles platform differences: live MobileScanner camera on '
            'mobile (width < 600 px), manual UPC TextField entry on desktop',
        'Suggests substitute products by querying the APL for eligible '
            'items in the same category via AplService.substitutes()',
        'Implements a busy flag in ScanScreen to prevent concurrent '
            'overlapping APL lookup requests',
        'Syncs FirebaseAuth User changes into AppState through '
            'ChangeNotifierProxyProvider in the root widget',
      ],

      // ------------------------------------------------------------------ //
      // B — BENEFIT                                                          //
      // ------------------------------------------------------------------ //
      benefitsFound: [
        'canAdd() guard prevents basket mutations that would exceed WIC '
            'category limits before any state is written',
        'On logout, _clear() resets balances and basket, preventing stale '
            'data from leaking between users',
        'Manual UPC entry fallback ensures the app remains functional on '
            'desktop / web platforms without a camera',
        'substitutes() method provides alternative product suggestions when '
            'a category limit is already reached',
        'Firestore set() with SetOptions(merge:true) preserves unrelated '
            'document fields on every persist',
        '_checkEligibility wraps the APL query in try/catch and surfaces '
            'failures as SnackBar messages to the user',
        'Busy flag in ScanScreen ensures only one APL lookup runs at a '
            'time, avoiding redundant Firestore reads',
        '_deriveAllowed() provides bounded defaults for new categories so '
            'the app functions correctly without pre-seeded server config',
        'First-time users automatically receive a Firestore document '
            'scaffold on first login via _persist()',
        'GoRouterRefreshStream triggers route guard re-evaluation '
            'immediately after any auth-state change',
        'FakeFirebaseFirestore in tests fully isolates unit tests from '
            'live Firebase connections',
      ],

      // ------------------------------------------------------------------ //
      // C — CONTEXT                                                          //
      // ------------------------------------------------------------------ //
      contextAndScope: [
        '3 authenticated screens: ScanScreen, BasketScreen, BalancesScreen',
        '2 authentication screens: LoginScreen, SignupPage',
        '1 AppState ChangeNotifier managing basket list and balances map',
        '1 AplService with findByUpc() and substitutes() Firestore methods',
        '1 router file (app_router.dart) with GoRouter, ShellRoute, '
            'GoRouterRefreshStream, and auth redirect logic',
        '5 named routes: /login, /signup, /scan, /basket, /balances',
        'Packages integrated: firebase_core, firebase_auth, '
            'cloud_firestore, mobile_scanner, go_router, provider, '
            'qr_flutter, fake_async',
        'Dev packages: mockito, fake_cloud_firestore, build_runner, '
            'flutter_lints',
        'Firestore collections: users (per-user basket and balance data), '
            'apl (approved product list)',
        'Basket item format: Map with keys upc, name, category, qty',
        'Balance format: Map<String, Map<String, dynamic>> keyed by '
            'canonical uppercase category name with allowed and used fields',
        '7 test files: 5 screen widget tests, 1 state unit test, '
            '1 service unit test; mocks generated by Mockito build_runner',
        'CI pipeline: dart format check, flutter analyze, flutter test, '
            'dart doc generation, GitHub Pages deployment',
      ],

      // ------------------------------------------------------------------ //
      // D — DATA                                                             //
      // ------------------------------------------------------------------ //
      dataAndNumbers: [
        'Dairy default cap: 3 items (keywords: MILK, CHEESE, YOGURT, DAIRY)',
        'Bread / Grain / Cereal default cap: 2 items',
        'Protein default cap: 1 item (keywords: MEAT, BEAN, PEANUT)',
        'Juice default cap: 1 item (keyword: JUICE)',
        'Uncategorised default cap: 2 items',
        'CVB and Fruit / Vegetable categories: uncapped (allowed = null)',
        'Mobile vs desktop breakpoint: screen width < 600 logical pixels',
        'MobileScanner viewport: 280 × 280 logical pixels',
        'Maximum desktop card width: 500 logical pixels',
        'APL substitutes() default query limit: max = 3',
        'UPC TextField max length: 13 characters',
        'Progress bar green threshold: < 60 % used',
        'Progress bar orange threshold: 60 – 85 % used',
        'Progress bar red threshold: ≥ 85 % used',
        'Decrement used count clamped to range 0 – 999',
        'Primary brand colour: 0xFFD1001C',
        'App version: 1.0.0+1 (pubspec.yaml)',
        'Commented diagnostic test UPC: 000000743266',
        'Test coverage percentage: [NEEDS METRIC] — no coverage report '
            'is generated in the CI workflow',
      ],

      // ------------------------------------------------------------------ //
      // Suggested resume-ready facts (raw, not polished)                    //
      // ------------------------------------------------------------------ //
      suggestedFacts: [
        'Built a Flutter mobile/desktop app with live barcode scanning '
            '(MobileScanner) and Cloud Firestore integration to verify '
            'WIC product eligibility in real time',
        'Implemented per-category item-limit enforcement in AppState with '
            'automatic cap derivation (dairy=3, protein=1, default=2), '
            'preventing users from exceeding WIC benefit quotas',
        'Designed a GoRouter navigation system with Firebase Auth guards, '
            'a custom ChangeNotifier refresh stream, and a persistent '
            'ShellRoute bottom-nav shell across 5 routes',
        'Wired Firebase Auth state changes into app-wide ChangeNotifier '
            'state via ChangeNotifierProxyProvider, triggering automatic '
            'Firestore data load on login and state clear on logout',
        'Achieved [NEEDS METRIC] test coverage across 7 test files '
            'covering widget tests, state unit tests, and service unit '
            'tests using FakeFirebaseFirestore and Mockito-generated mocks',
      ],
    );
  }
}
