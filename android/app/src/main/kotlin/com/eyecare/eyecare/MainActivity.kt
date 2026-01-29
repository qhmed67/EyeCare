package com.eyecare.eyecare

import androidx.annotation.NonNull
import com.eyecare.eyecare.ai.EyeAnalysisPipeline
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.eyecare.ai/analysis"
    private var pipeline: EyeAnalysisPipeline? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        pipeline = EyeAnalysisPipeline(context)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startAnalysis") {
                val imagePath = call.argument<String>("imagePath")
                if (imagePath != null) {
                    // Run AI analysis on a background thread to keep UI smooth
                    CoroutineScope(Dispatchers.Default).launch {
                        val analysisResult = pipeline?.analyze(imagePath) ?: mapOf(
                            "success" to false,
                            "errorMessage" to "Pipeline not initialized"
                        )
                        
                        withContext(Dispatchers.Main) {
                            result.success(analysisResult)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "ImagePath is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        pipeline?.close()
    }
}
