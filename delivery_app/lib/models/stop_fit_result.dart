enum StopFitClassification { excellent, good, tight, mismatch }

class StopFitResult {
  const StopFitResult(
    this.classification,
    this.explanation,
    this.estimatedMinutes,
    this.marginMinutes,
  );
  final StopFitClassification classification;
  final String explanation;
  final int estimatedMinutes;
  final int marginMinutes;
  String get label => switch (classification) {
    StopFitClassification.excellent => 'EXCELLENT FIT',
    StopFitClassification.good => 'GOOD FIT',
    StopFitClassification.tight => 'TIGHT TIMING',
    StopFitClassification.mismatch => 'ROUTE MISMATCH',
  };
}
