package org.discoos.ringdrill

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.net.toFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val channel = "ringdrill/shared_file"
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        handleSharedFile(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSharedFile(intent)
    }

    private fun handleSharedFile(intent: Intent?) {
        val uri: Uri = intent?.data ?: return
        val mime = intent.type ?: ""

        if (!uri.toString().endsWith(".drill") && mime != "application/x-drill") return

        try {
            // If it's a content:// URI, copy to temp file
            val inputStream = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val filename = uri.lastPathSegment?.split("/")?.lastOrNull() ?: "shared.drill"
                val tempFile = File.createTempFile("shared_", ".drill", cacheDir)
                FileOutputStream(tempFile).use { output ->
                    inputStream.copyTo(output)
                }

                methodChannel.invokeMethod("onSharedFilePath", tempFile.absolutePath)
            } else {
                // If it's a file:// URI we might get a direct path
                val file = uri.toFile()
                methodChannel.invokeMethod("onSharedFilePath", file.absolutePath)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            methodChannel.invokeMethod("onSharedFileError", e.message ?: "Unknown error")
        }
    }
}
