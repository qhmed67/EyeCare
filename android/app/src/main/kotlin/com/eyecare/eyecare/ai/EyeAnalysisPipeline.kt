package com.eyecare.eyecare.ai

import android.content.Context
import android.graphics.Bitmap
import android.util.Log

/**
 * Eye-First Analysis Pipeline.
 * 
 * This pipeline treats the EYE as a first-class object, not the face.
 * It works with:
 * - Full face images
 * - Single eye crops
 * - Macro close-ups of iris
 * 
 * Detection flow:
 * 1. MediaPipe FaceLandmarker (iris landmarks, ignoring face validity)
 * 2. Deterministic Fallback (LAB/HSV color + geometry)
 * 3. Multi-signal Confidence Scoring
 */
class EyeAnalysisPipeline(private val context: Context) {
    
    companion object {
        private const val TAG = "EyeAnalysisPipeline"
    }
    
    private val eyeDetector = EyeRegionDetector(context)
    private val fallback = DeterministicFallback()
    private val confidenceScorer = ConfidenceScorer()
    
    /**
     * Analyze an image for eye health indicators.
     * Returns results even for single-eye or close-up images.
     */
    fun analyze(imagePath: String): Map<String, Any> {
        Log.d(TAG, "Starting eye-first analysis: $imagePath")
        
        val bitmap = ImageUtils.decodeBitmap(imagePath) 
            ?: return errorResult(
                "Could not decode image",
                FailureStage.MEDIAPIPE_INIT,
                mapOf("path" to imagePath)
            )
        
        // STAGE 1: MediaPipe Eye Detection (Primary)
        val mediapipeResult = eyeDetector.detectEyeRegions(bitmap)
        
        // STAGE 2: Deterministic Fallback (if MediaPipe fails or for validation)
        val fallbackResult = fallback.analyzeRegion(bitmap, null)
        
        // Determine which eye candidate to use
        val primaryCandidate = mediapipeResult.eyeCandidates.firstOrNull()
        
        // STAGE 3: Calculate redness for health analysis
        val rednessScore = if (primaryCandidate != null) {
            fallback.analyzeRedness(bitmap, primaryCandidate)
        } else {
            fallback.analyzeRedness(bitmap, null)
        }
        
        // STAGE 4: Confidence scoring
        val confidence = confidenceScorer.calculate(
            primaryCandidate,
            fallbackResult,
            rednessScore
        )
        
        // Decision: Do we have a valid eye?
        val hasValidEye = mediapipeResult.success || fallbackResult.isEye
        
        if (!hasValidEye) {
            return errorResult(
                mediapipeResult.errorReason ?: "Eye detection inconclusive",
                mediapipeResult.errorStage ?: FailureStage.GEOMETRY_VALIDATION,
                fallbackResult.diagnostics
            )
        }
        
        // STAGE 5: Health scoring based on detected features
        val healthScores = calculateHealthScores(
            rednessScore = rednessScore,
            eyeCandidate = primaryCandidate,
            confidence = confidence.overall
        )
        
        // Determine detection method
        val method = when {
            mediapipeResult.success && fallbackResult.isEye -> DetectionMethod.HYBRID
            mediapipeResult.success -> DetectionMethod.MEDIAPIPE_IRIS
            else -> DetectionMethod.DETERMINISTIC_FALLBACK
        }
        
        Log.d(TAG, "Analysis complete: method=$method, confidence=${confidence.overall}")
        
        return buildSuccessResult(healthScores, confidence, method, rednessScore)
    }
    
    private fun calculateHealthScores(
        rednessScore: Float,
        eyeCandidate: EyeCandidate?,
        confidence: Float
    ): HealthScores {
        // Fatigue: Based on eye aperture (if available)
        val fatigueScore = if (eyeCandidate != null && eyeCandidate.contourPoints.size >= 10) {
            val contour = eyeCandidate.contourPoints
            val box = eyeCandidate.boundingBox
            val apertureRatio = box.height() / box.width().coerceAtLeast(1f)
            // Normal eye: ratio ~0.3-0.5, Fatigued: <0.25
            val fatigueRaw = ((0.5f - apertureRatio) * 200).coerceIn(0f, 100f)
            mapScoreToUserBands(fatigueRaw)
        } else {
            // Fallback: moderate estimate
            50
        }
        
        // Dry Eye: Based on shape consistency and symmetry
        val dryEyeScore = if (eyeCandidate != null) {
            val iris = eyeCandidate.irisData
            // Check iris centration (off-center may indicate strain)
            val box = eyeCandidate.boundingBox
            val expectedCenterX = box.centerX()
            val actualCenterX = iris.center.x
            val deviation = kotlin.math.abs(expectedCenterX - actualCenterX) / box.width()
            val dryEyeRaw = (deviation * 150).coerceIn(0f, 100f)
            mapScoreToUserBands(dryEyeRaw)
        } else {
            45
        }
        
        // Inflammation: Directly from redness analysis
        val inflammationScore = mapScoreToUserBands(rednessScore)
        
        return HealthScores(
            fatigue = fatigueScore,
            dryEye = dryEyeScore,
            inflammation = inflammationScore
        )
    }
    
    private fun mapScoreToUserBands(rawScore: Float): Int {
        // Input Raw Score: 0 (Good) -> 100 (Bad)
        // Output: 0-75 (Natural), 76-85 (Moderate), 86-100 (Risk)
        return when {
            rawScore < 40 -> (rawScore * 1.875f).toInt()  // 0-40 -> 0-75
            rawScore < 70 -> 76 + ((rawScore - 40) * 0.3f).toInt()  // 40-70 -> 76-85
            else -> 86 + ((rawScore - 70) * 0.46f).toInt().coerceAtMost(100)  // 70-100 -> 86-100
        }
    }
    
    private fun buildSuccessResult(
        scores: HealthScores,
        confidence: EyeConfidenceScore,
        method: DetectionMethod,
        rednessRaw: Float
    ): Map<String, Any> {
        fun getLabel(score: Int) = when {
            score > 85 -> "High Indicator"
            score > 75 -> "Moderate Indicator"
            else -> "Low Risk"
        }
        
        fun getSummary(condition: String, score: Int): String {
            val status = when {
                score < 50 -> "Low indicators detected. Your eyes appear healthy based on visible signals."
                score < 80 -> "Moderate indicators detected. Possible signs of strain or minor irritation observed."
                else -> "High indicators detected. Significant visible signs of stress, redness, or fatigue were identified."
            }
            return "$status Analysis confidence: ${String.format("%.0f", confidence.overall * 100)}%"
        }
        
        val results = listOf(
            mapOf(
                "condition" to EyeAnalysisConstants.CONDITION_FATIGUE,
                "riskPercentage" to scores.fatigue.toDouble(),
                "confidenceScore" to confidence.overall.toDouble(),
                "prevalence" to EyeAnalysisConstants.PREVALENCE_FATIGUE,
                "commonSymptoms" to EyeAnalysisConstants.SYMPTOMS_FATIGUE,
                "insights" to "${getSummary(EyeAnalysisConstants.CONDITION_FATIGUE, scores.fatigue)}\n\n${EyeAnalysisConstants.INSIGHTS_FATIGUE}"
            ),
            mapOf(
                "condition" to EyeAnalysisConstants.CONDITION_DRY_EYE,
                "riskPercentage" to scores.dryEye.toDouble(),
                "confidenceScore" to confidence.overall.toDouble(),
                "prevalence" to EyeAnalysisConstants.PREVALENCE_DRY_EYE,
                "commonSymptoms" to EyeAnalysisConstants.SYMPTOMS_DRY_EYE,
                "insights" to "${getSummary(EyeAnalysisConstants.CONDITION_DRY_EYE, scores.dryEye)}\n\n${EyeAnalysisConstants.INSIGHTS_DRY_EYE}"
            ),
            mapOf(
                "condition" to EyeAnalysisConstants.CONDITION_INFLAMMATION,
                "riskPercentage" to scores.inflammation.toDouble(),
                "confidenceScore" to confidence.overall.toDouble(),
                "prevalence" to EyeAnalysisConstants.PREVALENCE_INFLAMMATION,
                "commonSymptoms" to EyeAnalysisConstants.SYMPTOMS_INFLAMMATION,
                "insights" to "${getSummary(EyeAnalysisConstants.CONDITION_INFLAMMATION, scores.inflammation)}\n\n${EyeAnalysisConstants.INSIGHTS_INFLAMMATION}"
            )
        )
        
        return mapOf(
            "success" to true,
            "results" to results,
            "detectionMethod" to method.name,
            "confidence" to mapOf(
                "overall" to confidence.overall,
                "landmark" to confidence.landmarkScore,
                "color" to confidence.colorScore,
                "geometry" to confidence.geometryScore,
                "explanation" to confidence.explanation
            ),
            "metrics" to mapOf(
                "rednessRaw" to rednessRaw,
                "fatigueScore" to scores.fatigue,
                "dryEyeScore" to scores.dryEye,
                "inflammationScore" to scores.inflammation
            )
        )
    }
    
    private fun errorResult(
        message: String,
        stage: FailureStage,
        diagnostics: Map<String, Any>
    ): Map<String, Any> {
        Log.w(TAG, "Detection failed at $stage: $message")
        return mapOf(
            "success" to false,
            "errorType" to "detection_inconclusive",
            "errorMessage" to message,
            "failedStage" to stage.name,
            "diagnostics" to diagnostics
        )
    }
    
    fun close() {
        eyeDetector.close()
    }
}

private data class HealthScores(
    val fatigue: Int,
    val dryEye: Int,
    val inflammation: Int
)
