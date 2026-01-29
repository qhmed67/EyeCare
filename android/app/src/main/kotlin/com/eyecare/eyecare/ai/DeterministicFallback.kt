package com.eyecare.eyecare.ai

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PointF
import android.graphics.RectF
import android.util.Log
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Deterministic computer vision fallback for eye detection.
 * Uses LAB and HSV color space analysis with geometric validation.
 * 
 * NO ML DEPENDENCY - purely rule-based, explainable detection.
 */
class DeterministicFallback {
    
    companion object {
        private const val TAG = "DeterministicFallback"
        
        // Sclera detection thresholds (LAB color space)
        private const val SCLERA_L_MIN = 40f      // Lowered from 65: Allow dimmer lighting
        private const val SCLERA_A_MAX = 30f       // Increased from 20: Allow more redness (inflammation)
        private const val SCLERA_SATURATION_MAX = 0.4f  // Increased from 0.25: Allow more color variance
        
        // Iris detection thresholds
        private const val IRIS_L_MAX = 75f         // Increased from 50: Allow lighter eyes/hazel
        private const val IRIS_CIRCULARITY_MIN = 0.4f // Lowered from 0.6: Allow partial/obstructed iris
        
        // Geometry thresholds
        private const val EYE_ASPECT_RATIO_MIN = 0.5f // Lowered from 1.5: Support square/vertical crops
        private const val EYE_ASPECT_RATIO_MAX = 4.0f
    }
    
    /**
     * Analyze a region to determine if it contains an eye.
     * Returns confidence score and diagnostic metadata.
     */
    fun analyzeRegion(bitmap: Bitmap, region: RectF? = null): FallbackResult {
        val analysisRegion = region ?: RectF(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat())
        
        return try {
            // Step 1: Color space analysis
            val colorAnalysis = analyzeColorSpaces(bitmap, analysisRegion)
            
            // Step 2: Sclera detection (white of eye)
            val scleraResult = detectSclera(colorAnalysis)
            
            // Step 3: Iris detection (dark circular region)
            val irisResult = detectIrisCenterFromColorMap(colorAnalysis)
            
            // Step 4: Geometry validation
            val geometryResult = validateGeometry(scleraResult, irisResult, analysisRegion)
            
            // Step 5: Calculate overall confidence
            val confidence = calculateConfidence(colorAnalysis, scleraResult, irisResult, geometryResult)
            
            // Decision: Is this an eye?
            // Relaxed threshold: 0.3f (was 0.4f) to capture difficult cases
            val isEye = confidence.overall >= 0.3f && 
                       (scleraResult.detected || irisResult.detected)
            
            FallbackResult(
                isEye = isEye,
                confidence = confidence,
                colorAnalysis = colorAnalysis,
                scleraDetected = scleraResult.detected,
                irisDetected = irisResult.detected,
                geometryValid = geometryResult.valid,
                estimatedIrisCenter = irisResult.center,
                diagnostics = buildDiagnostics(colorAnalysis, scleraResult, irisResult, geometryResult)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Fallback analysis failed: ${e.message}")
            FallbackResult(
                isEye = false,
                confidence = FallbackConfidence(0f, 0f, 0f, 0f),
                diagnostics = mapOf("error" to (e.message ?: "Unknown error"))
            )
        }
    }
    
    /**
     * Analyze redness of the sclera region for inflammation detection.
     * Returns normalized redness score (0-100).
     */
    fun analyzeRedness(bitmap: Bitmap, eyeCandidate: EyeCandidate? = null): Float {
        val region = eyeCandidate?.boundingBox ?: RectF(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat())
        
        var totalRedness = 0f
        var scleraPixelCount = 0
        
        val startX = region.left.toInt().coerceIn(0, bitmap.width - 1)
        val endX = region.right.toInt().coerceIn(0, bitmap.width - 1)
        val startY = region.top.toInt().coerceIn(0, bitmap.height - 1)
        val endY = region.bottom.toInt().coerceIn(0, bitmap.height - 1)
        
        for (y in startY until endY) {
            for (x in startX until endX) {
                val pixel = bitmap.getPixel(x, y)
                val lab = rgbToLab(pixel)
                
                // Only analyze sclera-like pixels (high luminance, low saturation)
                if (lab.l > SCLERA_L_MIN) {
                    // LAB a* channel: positive = red, negative = green
                    if (lab.a > 0) {
                        totalRedness += lab.a
                        scleraPixelCount++
                    }
                }
            }
        }
        
        return if (scleraPixelCount > 0) {
            // Normalize: typical healthy sclera a* = 2-8, inflamed = 15-30+
            val avgRedness = totalRedness / scleraPixelCount
            (avgRedness * 3.5f).coerceIn(0f, 100f)
        } else {
            15f  // Default moderate value if no sclera detected
        }
    }
    
    private fun analyzeColorSpaces(bitmap: Bitmap, region: RectF): ColorSpaceAnalysis {
        val startX = region.left.toInt().coerceIn(0, bitmap.width - 1)
        val endX = region.right.toInt().coerceIn(0, bitmap.width)
        val startY = region.top.toInt().coerceIn(0, bitmap.height - 1)
        val endY = region.bottom.toInt().coerceIn(0, bitmap.height)
        
        val width = endX - startX
        val height = endY - startY
        
        if (width <= 0 || height <= 0) {
            return ColorSpaceAnalysis(emptyList(), emptyList(), 0, 0)
        }
        
        val labPixels = mutableListOf<LabPixel>()
        val hsvPixels = mutableListOf<HsvPixel>()
        
        for (y in startY until endY) {
            for (x in startX until endX) {
                val pixel = bitmap.getPixel(x, y)
                val localX = x - startX
                val localY = y - startY
                
                labPixels.add(LabPixel(localX, localY, rgbToLab(pixel)))
                hsvPixels.add(HsvPixel(localX, localY, rgbToHsv(pixel)))
            }
        }
        
        return ColorSpaceAnalysis(labPixels, hsvPixels, width, height)
    }
    
    private fun detectSclera(analysis: ColorSpaceAnalysis): ScleraResult {
        val scleraPixels = analysis.labPixels.filter { pixel ->
            pixel.lab.l > SCLERA_L_MIN && abs(pixel.lab.a) < SCLERA_A_MAX
        }
        
        val scleraRatio = scleraPixels.size.toFloat() / analysis.labPixels.size.coerceAtLeast(1)
        
        return ScleraResult(
            detected = scleraRatio > 0.1f,  // At least 10% sclera-like pixels
            coverage = scleraRatio,
            avgLuminance = scleraPixels.map { it.lab.l }.average().toFloat().takeIf { !it.isNaN() } ?: 0f
        )
    }
    
    private fun detectIrisCenterFromColorMap(analysis: ColorSpaceAnalysis): IrisDetectionResult {
        // Find dark cluster that could be iris
        val darkPixels = analysis.labPixels.filter { it.lab.l < IRIS_L_MAX }
        
        if (darkPixels.size < analysis.labPixels.size * 0.03) {
            return IrisDetectionResult(detected = false)
        }
        
        // Find centroid of dark region
        val avgX = darkPixels.map { it.x }.average().toFloat()
        val avgY = darkPixels.map { it.y }.average().toFloat()
        
        // Estimate radius from dark pixel spread
        val distances = darkPixels.map { 
            sqrt((it.x - avgX) * (it.x - avgX) + (it.y - avgY) * (it.y - avgY))
        }
        val estimatedRadius = distances.average().toFloat()
        
        // Check circularity (standard deviation of distances should be low for circle)
        val distStdDev = sqrt(distances.map { (it - estimatedRadius) * (it - estimatedRadius) }.average()).toFloat()
        val circularity = 1f - (distStdDev / estimatedRadius.coerceAtLeast(1f)).coerceIn(0f, 1f)
        
        return IrisDetectionResult(
            detected = circularity > IRIS_CIRCULARITY_MIN,
            center = PointF(avgX, avgY),
            estimatedRadius = estimatedRadius,
            circularity = circularity
        )
    }
    
    private fun validateGeometry(
        sclera: ScleraResult,
        iris: IrisDetectionResult,
        region: RectF
    ): GeometryResult {
        val aspectRatio = region.width() / region.height().coerceAtLeast(1f)
        val aspectValid = aspectRatio in EYE_ASPECT_RATIO_MIN..EYE_ASPECT_RATIO_MAX
        
        // Check horizontal symmetry (sclera should be on both sides of iris)
        val horizontalSymmetry = if (iris.detected && iris.center != null) {
            val leftSpace = iris.center.x
            val rightSpace = region.width() - iris.center.x
            val symmetryRatio = minOf(leftSpace, rightSpace) / maxOf(leftSpace, rightSpace).coerceAtLeast(1f)
            symmetryRatio > 0.3f
        } else false
        
        return GeometryResult(
            valid = aspectValid || (sclera.detected && iris.detected),
            aspectRatio = aspectRatio,
            horizontalSymmetry = horizontalSymmetry
        )
    }
    
    private fun calculateConfidence(
        color: ColorSpaceAnalysis,
        sclera: ScleraResult,
        iris: IrisDetectionResult,
        geometry: GeometryResult
    ): FallbackConfidence {
        val colorScore = if (sclera.detected) {
            (sclera.coverage * 2).coerceIn(0f, 1f)
        } else 0.2f
        
        val landmarkScore = if (iris.detected) {
            iris.circularity.coerceIn(0f, 1f)
        } else 0f
        
        val geometryScore = when {
            geometry.valid && geometry.horizontalSymmetry -> 1f
            geometry.valid -> 0.6f
            else -> 0.2f
        }
        
        // Weighted average (same as ConfidenceScorer)
        val overall = (landmarkScore * 0.40f) + (colorScore * 0.35f) + (geometryScore * 0.25f)
        
        return FallbackConfidence(
            overall = overall,
            colorScore = colorScore,
            landmarkProxyScore = landmarkScore,
            geometryScore = geometryScore
        )
    }
    
    private fun buildDiagnostics(
        color: ColorSpaceAnalysis,
        sclera: ScleraResult,
        iris: IrisDetectionResult,
        geometry: GeometryResult
    ): Map<String, Any> {
        return mapOf(
            "scleraDetected" to sclera.detected,
            "scleraCoverage" to String.format("%.1f%%", sclera.coverage * 100),
            "irisDetected" to iris.detected,
            "irisCircularity" to String.format("%.2f", iris.circularity),
            "aspectRatio" to String.format("%.2f", geometry.aspectRatio),
            "expectedAspectRange" to "$EYE_ASPECT_RATIO_MIN-$EYE_ASPECT_RATIO_MAX",
            "horizontalSymmetry" to geometry.horizontalSymmetry,
            "analysisMethod" to "LAB+HSV color space with geometric validation"
        )
    }
    
    // Color conversion utilities
    
    private fun rgbToLab(pixel: Int): Lab {
        val r = Color.red(pixel) / 255f
        val g = Color.green(pixel) / 255f
        val b = Color.blue(pixel) / 255f
        
        // RGB to XYZ (sRGB D65)
        fun pivotRgb(n: Float) = if (n > 0.04045f) {
            Math.pow(((n + 0.055) / 1.055).toDouble(), 2.4).toFloat()
        } else n / 12.92f
        
        val rLin = pivotRgb(r)
        val gLin = pivotRgb(g)
        val bLin = pivotRgb(b)
        
        val x = rLin * 0.4124564f + gLin * 0.3575761f + bLin * 0.1804375f
        val y = rLin * 0.2126729f + gLin * 0.7151522f + bLin * 0.0721750f
        val z = rLin * 0.0193339f + gLin * 0.1191920f + bLin * 0.9503041f
        
        // XYZ to LAB (D65 reference white)
        fun pivotXyz(n: Float) = if (n > 0.008856f) {
            Math.cbrt(n.toDouble()).toFloat()
        } else (7.787f * n) + (16f / 116f)
        
        val xN = pivotXyz(x / 0.95047f)
        val yN = pivotXyz(y / 1.00000f)
        val zN = pivotXyz(z / 1.08883f)
        
        return Lab(
            l = (116f * yN) - 16f,
            a = 500f * (xN - yN),
            b = 200f * (yN - zN)
        )
    }
    
    private fun rgbToHsv(pixel: Int): Hsv {
        val hsv = FloatArray(3)
        Color.colorToHSV(pixel, hsv)
        return Hsv(h = hsv[0], s = hsv[1], v = hsv[2])
    }
}

// Data classes for fallback analysis

data class Lab(val l: Float, val a: Float, val b: Float)
data class Hsv(val h: Float, val s: Float, val v: Float)

data class LabPixel(val x: Int, val y: Int, val lab: Lab)
data class HsvPixel(val x: Int, val y: Int, val hsv: Hsv)

data class ColorSpaceAnalysis(
    val labPixels: List<LabPixel>,
    val hsvPixels: List<HsvPixel>,
    val width: Int,
    val height: Int
)

data class ScleraResult(
    val detected: Boolean,
    val coverage: Float = 0f,
    val avgLuminance: Float = 0f
)

data class IrisDetectionResult(
    val detected: Boolean,
    val center: PointF? = null,
    val estimatedRadius: Float = 0f,
    val circularity: Float = 0f
)

data class GeometryResult(
    val valid: Boolean,
    val aspectRatio: Float = 0f,
    val horizontalSymmetry: Boolean = false
)

data class FallbackConfidence(
    val overall: Float,
    val colorScore: Float,
    val landmarkProxyScore: Float,
    val geometryScore: Float
)

data class FallbackResult(
    val isEye: Boolean,
    val confidence: FallbackConfidence,
    val colorAnalysis: ColorSpaceAnalysis? = null,
    val scleraDetected: Boolean = false,
    val irisDetected: Boolean = false,
    val geometryValid: Boolean = false,
    val estimatedIrisCenter: PointF? = null,
    val diagnostics: Map<String, Any> = emptyMap()
)
