package com.eyecare.eyecare.ai

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PointF
import android.graphics.RectF
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult

/**
 * Face-independent eye region detection using MediaPipe FaceLandmarker.
 * 
 * CRITICAL: This detector ignores face validity scores.
 * If iris landmarks are present, the eye is considered VALID regardless of face confidence.
 */
class EyeRegionDetector(private val context: Context) {
    
    companion object {
        private const val TAG = "EyeRegionDetector"
        
        // MediaPipe FaceLandmarker iris landmark indices
        // Left iris: 468-472 (5 points: center + 4 cardinal)
        // Right iris: 473-477 (5 points: center + 4 cardinal)
        private val LEFT_IRIS_INDICES = listOf(468, 469, 470, 471, 472)
        private val RIGHT_IRIS_INDICES = listOf(473, 474, 475, 476, 477)
        
        // Eye contour indices (16 points each)
        private val LEFT_EYE_CONTOUR = listOf(33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246)
        private val RIGHT_EYE_CONTOUR = listOf(362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398)
    }
    
    private var faceLandmarker: FaceLandmarker? = null
    
    init {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("face_landmarker.task")
                .build()
            
            val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.1f)  // Very low - we don't care about face
                .setMinFacePresenceConfidence(0.1f)   // Very low - we care about iris only
                .setMinTrackingConfidence(0.1f)
                .setOutputFaceBlendshapes(false)
                .setOutputFacialTransformationMatrixes(false)
                .build()
            
            faceLandmarker = FaceLandmarker.createFromOptions(context, options)
            Log.d(TAG, "MediaPipe FaceLandmarker initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize FaceLandmarker: ${e.message}")
        }
    }
    
    /**
     * Detect eye regions from bitmap.
     * Returns eye candidates even if face score is zero, as long as iris landmarks exist.
     */
    fun detectEyeRegions(bitmap: Bitmap): EyeDetectionResult {
        val landmarker = faceLandmarker ?: return EyeDetectionResult(
            success = false,
            errorStage = FailureStage.MEDIAPIPE_INIT,
            errorReason = "FaceLandmarker not initialized"
        )
        
        return try {
            val mpImage = BitmapImageBuilder(bitmap).build()
            val result = landmarker.detect(mpImage)
            
            extractEyeData(result, bitmap.width, bitmap.height)
        } catch (e: Exception) {
            Log.e(TAG, "Detection failed: ${e.message}")
            EyeDetectionResult(
                success = false,
                errorStage = FailureStage.LANDMARK_EXTRACTION,
                errorReason = "MediaPipe detection failed: ${e.message}"
            )
        }
    }
    
    private fun extractEyeData(result: FaceLandmarkerResult, width: Int, height: Int): EyeDetectionResult {
        if (result.faceLandmarks().isEmpty()) {
            return EyeDetectionResult(
                success = false,
                errorStage = FailureStage.LANDMARK_EXTRACTION,
                errorReason = "No landmarks detected - image may not contain recognizable eye features"
            )
        }
        
        val landmarks = result.faceLandmarks()[0]
        
        // Extract iris data - THIS IS THE PRIMARY SUCCESS CRITERIA
        val leftIris = extractIrisData(landmarks, LEFT_IRIS_INDICES, width, height)
        val rightIris = extractIrisData(landmarks, RIGHT_IRIS_INDICES, width, height)
        
        // CRITICAL: If at least one iris is detected, we consider it a SUCCESS
        // regardless of face detection confidence
        val hasValidIris = leftIris != null || rightIris != null
        
        if (!hasValidIris) {
            return EyeDetectionResult(
                success = false,
                errorStage = FailureStage.LANDMARK_EXTRACTION,
                errorReason = "Iris landmarks not detected - ensure eye is visible and in focus"
            )
        }
        
        // Extract eye contours for geometry analysis
        val leftContour = extractContour(landmarks, LEFT_EYE_CONTOUR, width, height)
        val rightContour = extractContour(landmarks, RIGHT_EYE_CONTOUR, width, height)
        
        // Build eye candidates
        val candidates = mutableListOf<EyeCandidate>()
        
        if (leftIris != null) {
            candidates.add(EyeCandidate(
                side = EyeSide.LEFT,
                irisData = leftIris,
                contourPoints = leftContour,
                boundingBox = calculateBoundingBox(leftContour, leftIris),
                detectionMethod = DetectionMethod.MEDIAPIPE_IRIS
            ))
        }
        
        if (rightIris != null) {
            candidates.add(EyeCandidate(
                side = EyeSide.RIGHT,
                irisData = rightIris,
                contourPoints = rightContour,
                boundingBox = calculateBoundingBox(rightContour, rightIris),
                detectionMethod = DetectionMethod.MEDIAPIPE_IRIS
            ))
        }
        
        return EyeDetectionResult(
            success = true,
            eyeCandidates = candidates,
            detectionMethod = DetectionMethod.MEDIAPIPE_IRIS
        )
    }
    
    private fun extractIrisData(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        indices: List<Int>,
        width: Int,
        height: Int
    ): IrisData? {
        return try {
            val points = indices.map { idx ->
                val lm = landmarks[idx]
                PointF(lm.x() * width, lm.y() * height)
            }
            
            val center = points[0]  // First point is always the iris center
            
            // Calculate radius from cardinal points
            val radius = listOf(
                distance(center, points[1]),
                distance(center, points[2]),
                distance(center, points[3]),
                distance(center, points[4])
            ).average().toFloat()
            
            IrisData(
                center = center,
                radius = radius,
                landmarks = points
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to extract iris data: ${e.message}")
            null
        }
    }
    
    private fun extractContour(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        indices: List<Int>,
        width: Int,
        height: Int
    ): List<PointF> {
        return try {
            indices.map { idx ->
                val lm = landmarks[idx]
                PointF(lm.x() * width, lm.y() * height)
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    private fun calculateBoundingBox(contour: List<PointF>, iris: IrisData): RectF {
        if (contour.isEmpty()) {
            // Fallback to iris-based bounding box
            val padding = iris.radius * 2
            return RectF(
                iris.center.x - padding,
                iris.center.y - padding,
                iris.center.x + padding,
                iris.center.y + padding
            )
        }
        
        val minX = contour.minOf { it.x }
        val maxX = contour.maxOf { it.x }
        val minY = contour.minOf { it.y }
        val maxY = contour.maxOf { it.y }
        
        return RectF(minX, minY, maxX, maxY)
    }
    
    private fun distance(p1: PointF, p2: PointF): Float {
        val dx = p1.x - p2.x
        val dy = p1.y - p2.y
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }
    
    fun close() {
        faceLandmarker?.close()
        faceLandmarker = null
    }
}

// Data classes for eye detection results

enum class EyeSide { LEFT, RIGHT }

enum class DetectionMethod {
    MEDIAPIPE_IRIS,
    DETERMINISTIC_FALLBACK,
    HYBRID
}

enum class FailureStage {
    MEDIAPIPE_INIT,
    LANDMARK_EXTRACTION,
    COLOR_ANALYSIS,
    GEOMETRY_VALIDATION
}

data class IrisData(
    val center: PointF,
    val radius: Float,
    val landmarks: List<PointF>
)

data class EyeCandidate(
    val side: EyeSide,
    val irisData: IrisData,
    val contourPoints: List<PointF>,
    val boundingBox: RectF,
    val detectionMethod: DetectionMethod
)

data class EyeDetectionResult(
    val success: Boolean,
    val eyeCandidates: List<EyeCandidate> = emptyList(),
    val detectionMethod: DetectionMethod? = null,
    val errorStage: FailureStage? = null,
    val errorReason: String? = null
)
