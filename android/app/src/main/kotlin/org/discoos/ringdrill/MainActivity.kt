package org.discoos.ringdrill

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
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
        Log.d("RingDrillShare", "handleSharedFile() intent=$intent")
        if (intent == null) return

        Log.d("RingDrillShare", "action=${intent.action} type=${intent.type} " +
                "hasExtra=${intent.hasExtra(Intent.EXTRA_STREAM)} " +
                "clipDataCount=${intent.clipData?.itemCount ?: 0} data=${intent.data}")

        // 1) Try ACTION_SEND: EXTRA_STREAM
        val fromExtra: Uri? = if (intent.action == Intent.ACTION_SEND)
            intent.getParcelableExtra(Intent.EXTRA_STREAM) else null

        // 2) Try ClipData (some apps put the stream there)
        val fromClip: Uri? = intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri

        // 3) Fallback to data (ACTION_VIEW etc.)
        val fromData: Uri? = intent.data

        val uri: Uri? = fromExtra ?: fromClip ?: fromData
        Log.d("RingDrillShare", "resolved uri=$uri (fromExtra=$fromExtra, fromClip=$fromClip, fromData=$fromData)")
        if (uri == null) {
            Log.w("RingDrillShare", "No URI found in intent")
            return
        }

        // Best-effort filename
        val filename = (uri.lastPathSegment?.substringAfterLast('/') ?: "shared.drill")
        Log.d("RingDrillShare", "filename guess: $filename")

        // Optional: accept only .drill
        if (!filename.endsWith(".drill", ignoreCase = true)) {
            Log.w("RingDrillShare", "Not a .drill file: $filename")
            // return  // <- uncomment to strictly enforce extension
        }

        try {
            when (uri.scheme) {
                "content" -> {
                    // Some providers require typed access; try InputStream first, then typed AFD
                    val inputStream = contentResolver.openInputStream(uri)
                        ?: contentResolver.openTypedAssetFileDescriptor(uri, "application/x-drill", null)?.createInputStream()
                        ?: contentResolver.openTypedAssetFileDescriptor(uri, "application/vnd.ringdrill+zip", null)?.createInputStream()

                    if (inputStream == null) {
                        Log.e("RingDrillShare", "Unable to open stream for $uri")
                        methodChannel.invokeMethod("onSharedFileError", "Unable to open stream")
                        return
                    }

                    val tempFile = File(cacheDir, if (filename.endsWith(".drill", true)) filename else "shared.drill")
                    Log.d("RingDrillShare", "Copying to: ${tempFile.absolutePath}")
                    inputStream.use { ins -> FileOutputStream(tempFile).use { outs -> ins.copyTo(outs) } }

                    methodChannel.invokeMethod("onSharedFilePath", tempFile.absolutePath)
                    Log.d("RingDrillShare", "Sent to Flutter: ${tempFile.absolutePath}")
                }
                "file" -> {
                    val file = uri.toFile()
                    methodChannel.invokeMethod("onSharedFilePath", file.absolutePath)
                    Log.d("RingDrillShare", "Sent to Flutter: ${file.absolutePath}")
                }
                else -> {
                    Log.w("RingDrillShare", "Unsupported scheme: ${uri.scheme}")
                }
            }
        } catch (e: Exception) {
            Log.e("RingDrillShare", "Error handling shared file", e)
            methodChannel.invokeMethod("onSharedFileError", e.message ?: "Unknown error")
        }
    }

}
