package com.eyecare.eyecare.ai

import android.graphics.PointF
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Multi-signal confidence scoring for medical-grade eye detection.
 * 
 * Formula: Score = (Landmark × 0.40) + (Color × 0.35) + (Geometry × 0.25)
 */
class ConfidenceScorer {
    
    companion object {
        private const val LANDMARK_WEIGHT = 0.40f
        private const val COLOR_WEIGHT = 0.35f
        private const val GEOMETRY_WEIGHT = 0.25f
        
        // Thresholds for quality assessment
        private const val IRIS_RADIUS_MIN = 5f
        private const val IRIS_RADIUS_MAX = 100f
        private const val CONTOUR_POINTS_MIN = 10
    }
    
    /**
     * Calculate unified confidence score from multiple detection sources.
     */
    fun calculate(
        eyeCandidate: EyeCandidate?,
        fallbackResult: FallbackResult?,
        rednessScore: Float
    ): EyeConfidenceScore {
        
        val landmarkScore = calculateLandmarkScore(eyeCandidate)
        val colorScore = calculateColorScore(fallbackResult, rednessScore)
        val geometryScore = calculateGeometryScore(eyeCandidate, fallbackResult)
        
        val overallScore = (landmarkScore * LANDMARK_WEIGHT) +
                          (colorScore * COLOR_WEIGHT) +
                          (geometryScore * GEOMETRY_WEIGHT)
        
        val explanation = generateExplanation(landmarkScore, colorScore, geometryScore, overallScore)
        
        return EyeConfidenceScore(
            overall = overallScore,
            landmarkScore = landmarkScore,
            colorScore = colorScore,
            geometryScore = geometryScore,
            explanation = explanation,
            breakdown = mapOf(
                "landmark" to landmarkScore,
                "color" to colorScore,
                "geometry" to geometryScore
            )
        )
    }
    
    private fun calculateLandmarkScore(eyeCandidate: EyeCandidate?): Float {
        if (eyeCandidate == null) return 0f
        
        val iris = eyeCandidate.irisData
        val contour = eyeCandidate.contourPoints
        
        var score = 0f
        
        // 1. Iris validity (40%)
        val irisValid = iris.radius in IRIS_RADIUS_MIN..IRIS_RADIUS_MAX
        if (irisValid) score += 0.4f
        
        // 2. Iris landmark consistency (30%)
        // Check if cardinal points are equidistant from center
        if (iris.landmarks.size >= 5) {
            val center = iris.center
            val distances = iris.landmarks.drop(1).map { distance(center, it) }
            val avgDist = distances.average().toFloat()
            val maxDeviation = distances.maxOfOrNull { abs(it - avgDist) } ?: avgDist
            val consistency = 1f - (maxDeviation / avgDist.coerceAtLeast(1f)).coerceIn(0f, 1f)
            score += consistency * 0.3f
        }
        
        // 3. Contour completeness (30%)
        val contourScore = (contour.size.toFloat() / 16f).coerceIn(0f, 1f)
        score += contourScore * 0.3f
        
        return score.coerceIn(0f, 1f)
    }
    
    private fun calculateColorScore(fallbackResult: FallbackResult?, rednessScore: Float): Float {
        var score = 0f
        
        // From fallback analysis
        if (fallbackResult != null) {
            if (fallbackResult.scleraDetected) score += 0.4f
            if (fallbackResult.irisDetected) score += 0.3f
            score += fallbackResult.confidence.colorScore * 0.3f
        } else {
            // Estimate from redness (if detectable redness, likely an eye)
            score = if (rednessScore in 5f..60f) 0.5f else 0.2f
        }
        
        return score.coerceIn(0f, 1f)
    }
    
    private fun calculateGeometryScore(
        eyeCandidate: EyeCandidate?,
        fallbackResult: FallbackResult?
    ): Float {
        var score = 0f
        
        // From MediaPipe contour
        if (eyeCandidate != null && eyeCandidate.contourPoints.size >= CONTOUR_POINTS_MIN) {
            val contour = eyeCandidate.contourPoints
            
            // Calculate aspect ratio from bounding box
            val box = eyeCandidate.boundingBox
            val aspectRatio = box.width() / box.height().coerceAtLeast(1f)
            
            // Eye aspect ratio typically 1.5-3.0, but allowing 0.5-4.0 for crops
            val aspectValid = aspectRatio in 0.5f..4.0f
            if (aspectValid) score += 0.5f
            
            // Check contour smoothness (no sharp angles)
            val smoothness = calculateContourSmoothness(contour)
            score += smoothness * 0.5f
        }
        
        // Supplement with fallback geometry
        if (fallbackResult != null && fallbackResult.geometryValid) {
            // Boost score if fallback geometry confirms it (especially if landmarks missing)
            score = (score + 0.5f).coerceAtMost(1f)
        }
        
        return score.coerceIn(0f, 1f)
    }
    
    private fun calculateContourSmoothness(points: List<PointF>): Float {
        if (points.size < 3) return 0f
        
        var totalAngleChange = 0f
        for (i in 1 until points.size - 1) {
            val v1 = PointF(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
            val v2 = PointF(points[i+1].x - points[i].x, points[i+1].y - points[i].y)
            
            val dot = v1.x * v2.x + v1.y * v2.y
            val mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
            val mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
            
            if (mag1 > 0 && mag2 > 0) {
                val cosAngle = (dot / (mag1 * mag2)).coerceIn(-1f, 1f)
                totalAngleChange += (1f - cosAngle)
            }
        }
        
        val avgAngleChange = totalAngleChange / (points.size - 2)
        // Lower angle change = smoother contour = higher score
        return (1f - avgAngleChange.coerceIn(0f, 1f))
    }
    
    private fun distance(p1: PointF, p2: PointF): Float {
        val dx = p1.x - p2.x
        val dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private fun generateExplanation(
        landmark: Float,
        color: Float,
        geometry: Float,
        overall: Float
    ): String {
        val level = when {
            overall >= 0.8f -> "High confidence"
            overall >= 0.5f -> "Moderate confidence"
            overall >= 0.3f -> "Low confidence"
            else -> "Very low confidence"
        }
        
        val factors = mutableListOf<String>()
        
        if (landmark >= 0.7f) factors.add("clear iris landmarks")
        else if (landmark >= 0.4f) factors.add("partial iris detection")
        else if (landmark > 0f) factors.add("weak landmark signal")
        
        if (color >= 0.7f) factors.add("typical eye coloration")
        else if (color >= 0.4f) factors.add("plausible sclera/iris colors")
        
        if (geometry >= 0.7f) factors.add("anatomically correct shape")
        else if (geometry >= 0.4f) factors.add("acceptable geometry")
        
        val factorText = if (factors.isNotEmpty()) {
            factors.joinToString(", ")
        } else "insufficient visual evidence"
        
        return "$level eye detection based on: $factorText."
    }
}

data class EyeConfidenceScore(
    val overall: Float,
    val landmarkScore: Float,
    val colorScore: Float,
    val geometryScore: Float,
    val explanation: String,
    val breakdown: Map<String, Float>
)
