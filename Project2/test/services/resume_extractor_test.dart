import 'package:flutter_test/flutter_test.dart';

import 'package:wolfbite/models/abcd_report.dart';
import 'package:wolfbite/services/resume_extractor.dart';

void main() {
  // ── AbcdReport model ──────────────────────────────────────────────────── //

  group('AbcdReport', () {
    const report = AbcdReport(
      projectName: 'Test Project',
      actionsFound: ['action 1', 'action 2'],
      benefitsFound: ['benefit 1'],
      contextAndScope: ['context 1'],
      dataAndNumbers: ['data 1'],
      suggestedFacts: ['fact 1', 'fact 2', 'fact 3'],
    );

    test('toFormattedString starts with PROJECT NAME header', () {
      final output = report.toFormattedString();
      expect(output.trimLeft(), startsWith('PROJECT NAME: Test Project'));
    });

    test('toFormattedString contains all section headers', () {
      final output = report.toFormattedString();
      expect(output, contains('ACTIONS FOUND:'));
      expect(output, contains('BENEFITS/IMPROVEMENTS FOUND:'));
      expect(output, contains('CONTEXT & SCOPE:'));
      expect(output, contains('DATA & NUMBERS FOUND:'));
      expect(output, contains('SUGGESTED RESUME-READY FACTS'));
    });

    test('toFormattedString lists every entry as a bullet', () {
      final output = report.toFormattedString();
      expect(output, contains('- action 1'));
      expect(output, contains('- action 2'));
      expect(output, contains('- benefit 1'));
      expect(output, contains('- context 1'));
      expect(output, contains('- data 1'));
      expect(output, contains('- fact 1'));
      expect(output, contains('- fact 2'));
      expect(output, contains('- fact 3'));
    });

    test('toFormattedString includes separator lines', () {
      final output = report.toFormattedString();
      expect(output, contains('---'));
    });

    test('toFormattedString works with empty lists', () {
      const empty = AbcdReport(
        projectName: 'Empty',
        actionsFound: [],
        benefitsFound: [],
        contextAndScope: [],
        dataAndNumbers: [],
        suggestedFacts: [],
      );
      final output = empty.toFormattedString();
      expect(output, contains('PROJECT NAME: Empty'));
      expect(output, contains('ACTIONS FOUND:'));
    });
  });

  // ── ResumeExtractorService ────────────────────────────────────────────── //

  group('ResumeExtractorService', () {
    late ResumeExtractorService service;

    setUp(() {
      service = const ResumeExtractorService();
    });

    test('extractAll returns a non-empty list', () {
      expect(service.extractAll(), isNotEmpty);
    });

    test('extractAll first entry is the WolfBite report', () {
      final first = service.extractAll().first;
      expect(first.projectName, contains('WolfBite'));
    });

    group('wolfbiteReport', () {
      late AbcdReport report;

      setUp(() {
        report = service.wolfbiteReport();
      });

      test('project name contains WolfBite', () {
        expect(report.projectName, contains('WolfBite'));
      });

      test('actionsFound is non-empty', () {
        expect(report.actionsFound, isNotEmpty);
      });

      test('benefitsFound is non-empty', () {
        expect(report.benefitsFound, isNotEmpty);
      });

      test('contextAndScope is non-empty', () {
        expect(report.contextAndScope, isNotEmpty);
      });

      test('dataAndNumbers is non-empty', () {
        expect(report.dataAndNumbers, isNotEmpty);
      });

      test('suggestedFacts has between 3 and 5 entries', () {
        expect(report.suggestedFacts.length, greaterThanOrEqualTo(3));
        expect(report.suggestedFacts.length, lessThanOrEqualTo(5));
      });

      test('actionsFound mentions barcode scanning', () {
        final text = report.actionsFound.join(' ').toLowerCase();
        expect(text, contains('barcode'));
      });

      test('actionsFound mentions Firestore', () {
        final text = report.actionsFound.join(' ').toLowerCase();
        expect(text, contains('firestore'));
      });

      test('dataAndNumbers contains dairy cap of 3', () {
        final text = report.dataAndNumbers.join(' ').toLowerCase();
        expect(text, contains('dairy'));
        expect(text, contains('3'));
      });

      test('dataAndNumbers contains NEEDS METRIC flag for coverage', () {
        final text = report.dataAndNumbers.join(' ').toLowerCase();
        expect(text, contains('[needs metric]'));
      });

      test('contextAndScope mentions route count', () {
        final text = report.contextAndScope.join(' ').toLowerCase();
        expect(text, contains('route'));
      });

      test('toFormattedString output is non-empty', () {
        final output = report.toFormattedString();
        expect(output.trim(), isNotEmpty);
      });
    });
  });
}
