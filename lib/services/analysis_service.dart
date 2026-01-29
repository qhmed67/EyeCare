import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/risk_result.dart';

/// Eye-First Analysis Service
///
/// Delegates all vision processing to native Kotlin layer.
/// Flutter handles only UI and result presentation.
class AnalysisService {
  static const _channel = MethodChannel('com.eyecare.ai/analysis');

  // Cloud Verification Config (OpenRouter)
  static const String _apiKey = "API KEY HERE ↓";
  static const String _model = "google/gemini-flash-1.5:free";
  static const String _baseUrl =
      "https://openrouter.ai/api/v1/chat/completions";

  /// Run eye analysis on an image file.
  /// Works with full-face, single-eye, and macro close-up images.
  Future<AnalysisOutput> runAnalysis(File imageFile) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'startAnalysis',
        {'imagePath': imageFile.path},
      );

      if (result == null) {
        return AnalysisOutput(
          success: false,
          humanEyeDetected: false,
          errorMessage: "Native pipeline returned null",
        );
      }

      // Deep convert ALL nested maps/lists from native
      final converted = _deepConvert(result);
      if (converted is! Map<String, dynamic>) {
        return AnalysisOutput(
          success: false,
          humanEyeDetected: false,
          errorMessage: "Failed to parse native result",
        );
      }

      final output = _parseNativeResult(converted);
      output.imagePath = imageFile.path; // Store path for Stage 2
      return output;
    } on PlatformException catch (e) {
      debugPrint("Platform error: ${e.message}");
      return AnalysisOutput(
        success: false,
        humanEyeDetected: false,
        errorMessage: "Platform error: ${e.message}",
      );
    } catch (e) {
      debugPrint("Analysis error: $e");
      return AnalysisOutput(
        success: false,
        humanEyeDetected: false,
        errorMessage: "Analysis failed: $e",
      );
    }
  }

  /// Deep convert any value from native (handles nested maps/lists recursively)
  dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (e) => MapEntry(e.key.toString(), _deepConvert(e.value)),
        ),
      );
    } else if (value is List) {
      return value.map((e) => _deepConvert(e)).toList();
    } else {
      return value;
    }
  }

  AnalysisOutput _parseNativeResult(Map<String, dynamic> data) {
    final success = data['success'] == true;

    if (!success) {
      return AnalysisOutput(
        success: false,
        humanEyeDetected: false,
        errorMessage: data['errorMessage']?.toString() ?? "Detection failed",
        diagnostics: data['diagnostics'] is Map<String, dynamic>
            ? data['diagnostics']
            : null,
        failedStage: data['failedStage']?.toString(),
      );
    }

    // Extract confidence data
    EyeConfidence? confidence;
    final confData = data['confidence'];
    if (confData is Map<String, dynamic>) {
      confidence = EyeConfidence(
        overall: _toDouble(confData['overall']),
        landmark: _toDouble(confData['landmark']),
        color: _toDouble(confData['color']),
        geometry: _toDouble(confData['geometry']),
        explanation: confData['explanation']?.toString() ?? "",
      );
    }

    // Parse results array
    final resultsList = data['results'];
    if (resultsList is! List || resultsList.isEmpty) {
      return AnalysisOutput(
        success: false,
        humanEyeDetected: true,
        errorMessage: "No analysis results returned",
      );
    }

    final results = resultsList.map((item) {
      if (item is Map<String, dynamic>) {
        return _createRiskResult(item);
      }
      return _createRiskResult({});
    }).toList();

    return AnalysisOutput(
      success: true,
      humanEyeDetected: true,
      isCloudAnalysis: false,
      results: results,
      detectionMethod: data['detectionMethod']?.toString(),
      confidence: confidence,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  RiskResult _createRiskResult(Map<String, dynamic> data) {
    final percentage = _toDouble(data['riskPercentage']);
    final label = _getLabel(percentage);
    final color = _getColor(label);

    return RiskResult(
      condition: data['condition']?.toString() ?? "Unknown",
      label: label,
      colorCode: color,
      riskPercentage: percentage,
      confidenceScore: _toDouble(data['confidenceScore']),
      prevalence: data['prevalence']?.toString() ?? "",
      commonSymptoms: _parseSymptoms(data['commonSymptoms']),
      insights: data['insights']?.toString() ?? "",
    );
  }

  String _getLabel(double score) {
    if (score > 85) return "High Indicator";
    if (score > 75) return "Moderate Indicator";
    return "Low Risk";
  }

  String _getColor(String label) {
    switch (label) {
      case "High Indicator":
        return "#F44336";
      case "Moderate Indicator":
        return "#FFC107";
      default:
        return "#4CAF50";
    }
  }

  List<String> _parseSymptoms(dynamic symptoms) {
    if (symptoms is List) {
      return symptoms.map((e) => e.toString()).toList();
    }
    if (symptoms is String) {
      return symptoms.split(', ');
    }
    return [];
  }

  /// Process Stage 2: Cloud Ensuring
  /// Checks if local indicators are within natural ranges via remote algorithm.
  Future<Map<String, dynamic>?> runCloudEnsuringStage(String imagePath) async {
    try {
      debugPrint("Starting Cloud Stage with model: $_model");
      final File file = File(imagePath);
      if (!await file.exists()) return null;

      final List<int> imageBytes = await file.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final Map<String, dynamic> requestBody = {
        "model": _model,
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text":
                    """
You are an expert computer vision system acting as a validation and enhancement layer for an eye analysis app.
${_getPromptTemplate()}
""",
              },
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
              },
            ],
          },
        ],
      };

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              "Authorization": "Bearer $_apiKey",
              "Content-Type": "application/json",
              "HTTP-Referer": "https://eyecare.ai", // Required by OpenRouter
              "X-Title": "EyeCare AI",
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content']
            .toString();
        return _extractJson(content);
      } else {
        debugPrint(
          "Cloud API Error: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
    } catch (e) {
      debugPrint("Cloud Analysis failed: $e");
      return null;
    }
  }

  /// Extracts JSON from a string that might contain markdown blocks
  Map<String, dynamic>? _extractJson(String text) {
    try {
      // Find JSON block if it's wrapped in markdown
      final jsonRegex = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegex.firstMatch(text);
      if (match != null) {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("JSON Extraction failed: $e\nOriginal text: $text");
      return null;
    }
  }

  String _getPromptTemplate() {
    return """
You are an expert computer vision system acting as a validation and enhancement layer for a fully offline-first eye analysis mobile application.

IMPORTANT CONTEXT:
- This system DOES NOT perform medical diagnosis.
- All outputs are risk indicators only.
- DO NOT assume the presence of a human face.

STEP 1: Eye Presence Classification
"Does this image contain at least one visible human eye (one or two)?"
- A single visible eye is sufficient.
- Partial eye structures (iris, sclera, eyelids) may be sufficient.

STEP 2: Conditional Indicator Analysis (ONLY IF YES)
Return THREE percentage-based indicators (0–100):
1. Eye Fatigue Risk (%) - Derived from eye openness, eyelid tension, squinting patterns.
2. Dry Eye Indicators (%) - Derived from sclera appearance, tear film irregularity, surface dullness.
3. Inflammation Indicator (%) - Derived from redness dominance, vascular visibility.

STEP 3: Output Formatting (STRICT JSON)
If YES:
{
  "eye_detected": true,
  "eye_fatigue_percent": <number>,
  "dry_eye_percent": <number>,
  "inflammation_percent": <number>,
  "confidence": <number between 0 and 1>,
  "notes": "Brief professional reasoning based on visual evidence"
}

If NO:
{
  "eye_detected": false,
  "confidence": <number between 0 and 1>,
  "notes": "Reason why no human eye structures were detected"
}

KEY CONSTRAINTS:
- Do NOT provide medical diagnosis.
- Do NOT mention diseases.
- Image is static.
- Return ONLY the JSON object. Do not include any introductory or concluding text.
""";
  }

  void dispose() {
    // No local resources to clean up
  }
}
