/// Structured ABCD resume framework report for a software project.
///
/// Captures raw, verifiable technical facts using the four-dimensional
/// ABCD framework:
///
/// - **A (Action)**: Technical actions performed — functions, algorithms,
///   patterns implemented.
/// - **B (Benefit)**: Problems solved, resilience patterns, error handling,
///   optimizations present.
/// - **C (Context)**: Scale and scope — API routes, libraries, data formats,
///   pipeline stages.
/// - **D (Data)**: Hardcoded numbers, thresholds, config values, and any
///   metrics that imply scale.
///
/// All entries are extracted directly from source code. Metrics that cannot
/// be confirmed from code are flagged with `[NEEDS METRIC]`.
class AbcdReport {
  const AbcdReport({
    required this.projectName,
    required this.actionsFound,
    required this.benefitsFound,
    required this.contextAndScope,
    required this.dataAndNumbers,
    required this.suggestedFacts,
  });

  /// Display name for the project being analysed.
  final String projectName;

  /// Technical actions performed in the project (A — ACTION).
  ///
  /// What major functions, classes, or modules actually do; algorithms and
  /// patterns implemented; meaningful technical verbs.
  final List<String> actionsFound;

  /// Problems solved or improvements made (B — BENEFIT).
  ///
  /// What would break without this component; error handling and fallback
  /// logic; caching, indexing, or optimisation patterns.
  final List<String> benefitsFound;

  /// Scale and scope of the project (C — CONTEXT).
  ///
  /// Number of API routes, models, or components; libraries and external
  /// services integrated; data formats handled; pipeline stages.
  final List<String> contextAndScope;

  /// Numbers found or inferred from source (D — DATA).
  ///
  /// Hardcoded limits, thresholds, timeouts, batch sizes; test coverage
  /// numbers; config values that imply scale.
  final List<String> dataAndNumbers;

  /// Raw bullet-ready facts combining A, B, C, and D dimensions.
  ///
  /// Not polished resume bullets — only directly verifiable combinations of
  /// the extracted facts above. Items that need a real metric are flagged
  /// with `[NEEDS METRIC]`.
  final List<String> suggestedFacts;

  /// Formats this report as a human-readable string.
  ///
  /// Output matches the structured report template required by the ABCD
  /// resume framework:
  ///
  /// ```
  /// PROJECT NAME: …
  /// ---
  /// ACTIONS FOUND:
  /// - …
  ///
  /// BENEFITS/IMPROVEMENTS FOUND:
  /// - …
  ///
  /// CONTEXT & SCOPE:
  /// - …
  ///
  /// DATA & NUMBERS FOUND:
  /// - …
  ///
  /// SUGGESTED RESUME-READY FACTS (raw, not polished):
  /// - …
  /// ---
  /// ```
  String toFormattedString() {
    final buf = StringBuffer();

    buf.writeln('PROJECT NAME: $projectName');
    buf.writeln('---');

    buf.writeln('ACTIONS FOUND:');
    for (final item in actionsFound) {
      buf.writeln('- $item');
    }
    buf.writeln();

    buf.writeln('BENEFITS/IMPROVEMENTS FOUND:');
    for (final item in benefitsFound) {
      buf.writeln('- $item');
    }
    buf.writeln();

    buf.writeln('CONTEXT & SCOPE:');
    for (final item in contextAndScope) {
      buf.writeln('- $item');
    }
    buf.writeln();

    buf.writeln('DATA & NUMBERS FOUND:');
    for (final item in dataAndNumbers) {
      buf.writeln('- $item');
    }
    buf.writeln();

    buf.writeln('SUGGESTED RESUME-READY FACTS (raw, not polished):');
    for (final item in suggestedFacts) {
      buf.writeln('- $item');
    }
    buf.writeln('---');

    return buf.toString();
  }
}
