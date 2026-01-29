class RiskResult {
  final String condition;
  final String label; // "Natural", "Moderate", or "Risk"
  final String colorCode; // HEX code for the label
  final double riskPercentage;
  final double confidenceScore;
  final String prevalence;
  final List<String> commonSymptoms;
  final String insights;

  RiskResult({
    required this.condition,
    required this.label,
    required this.colorCode,
    required this.riskPercentage,
    required this.confidenceScore,
    required this.prevalence,
    required this.commonSymptoms,
    required this.insights,
  });

  RiskResult copyWith({
    String? condition,
    String? label,
    String? colorCode,
    double? riskPercentage,
    double? confidenceScore,
    String? prevalence,
    List<String>? commonSymptoms,
    String? insights,
  }) {
    return RiskResult(
      condition: condition ?? this.condition,
      label: label ?? this.label,
      colorCode: colorCode ?? this.colorCode,
      riskPercentage: riskPercentage ?? this.riskPercentage,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      prevalence: prevalence ?? this.prevalence,
      commonSymptoms: commonSymptoms ?? this.commonSymptoms,
      insights: insights ?? this.insights,
    );
  }
}

class AnalysisOutput {
  final bool success;
  final bool humanEyeDetected;
  final bool isCloudAnalysis;
  final String? errorMessage;
  final List<RiskResult>? results;
  final String? detectionMethod;
  final EyeConfidence? confidence;
  final Map<String, dynamic>? diagnostics;
  final String? failedStage;
  String? imagePath;

  AnalysisOutput({
    required this.success,
    required this.humanEyeDetected,
    this.isCloudAnalysis = false,
    this.errorMessage,
    this.results,
    this.detectionMethod,
    this.confidence,
    this.diagnostics,
    this.failedStage,
    this.imagePath,
  });
}

class EyeConfidence {
  final double overall;
  final double landmark;
  final double color;
  final double geometry;
  final String explanation;

  EyeConfidence({
    required this.overall,
    required this.landmark,
    required this.color,
    required this.geometry,
    required this.explanation,
  });
}
