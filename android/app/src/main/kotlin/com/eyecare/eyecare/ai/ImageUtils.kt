package com.eyecare.eyecare.ai

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import java.nio.ByteBuffer
import java.nio.ByteOrder

object ImageUtils {
    fun decodeBitmap(path: String): Bitmap? {
        return BitmapFactory.decodeFile(path)
    }

    fun resizeBitmap(bitmap: Bitmap, width: Int, height: Int): Bitmap {
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }

    fun bitmapToByteBuffer(bitmap: Bitmap, width: Int, height: Int, mean: Float = 0f, std: Float = 255f): ByteBuffer {
        val byteBuffer = ByteBuffer.allocateDirect(4 * width * height * 3)
        byteBuffer.order(ByteOrder.nativeOrder())
        val intValues = IntArray(width * height)
        bitmap.getPixels(intValues, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        var pixel = 0
        for (i in 0 until width) {
            for (j in 0 until height) {
                val value = intValues[pixel++]
                byteBuffer.putFloat(((value shr 16 and 0xFF) - mean) / std)
                byteBuffer.putFloat(((value shr 8 and 0xFF) - mean) / std)
                byteBuffer.putFloat(((value and 0xFF) - mean) / std)
            }
        }
        return byteBuffer
    }

    // Heuristic for redness analysis using HSV
    fun analyzeRedness(bitmap: Bitmap): Float {
        var redPixels = 0
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        for (pixel in pixels) {
            val r = Color.red(pixel)
            val g = Color.green(pixel)
            val b = Color.blue(pixel)

            val hsv = FloatArray(3)
            Color.RGBToHSV(r, g, b, hsv)

            // Red hue is around 0-10 or 350-360
            if ((hsv[0] <= 15f || hsv[0] >= 345f) && hsv[1] > 0.3f && hsv[2] > 0.3f) {
                redPixels++
            }
        }
        return redPixels.toFloat() / (width * height)
    }
}
