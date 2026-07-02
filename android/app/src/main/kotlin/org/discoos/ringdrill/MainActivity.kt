package org.discoos.ringdrill

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.database.Cursor
import android.content.ContentResolver
import android.provider.OpenableColumns
import androidx.core.net.toFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val channel = "ringdrill/shared_file"
    private lateinit var methodChannel: MethodChannel

    // NEW: stash a copy of the incoming VIEW intent (with its data intact)
    private var pendingFileIntent: Intent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Capture + scrub BEFORE super so Flutter won’t see content://
        captureAndScrub(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "processIntentFile") {
                // Use your original handler
                handleSharedFile(pendingFileIntent ?: intent)
                // clear once processed
                pendingFileIntent = null
                result.success(null)
            }
        }

        // Cold start path: process any captured file once channel exists
        if (pendingFileIntent != null) {
            handleSharedFile(pendingFileIntent)
            pendingFileIntent = null
        }
    }

    override fun onNewIntent(newIntent: Intent) {
        // Capture + scrub BEFORE super so Flutter/go_router never sees content://
        captureAndScrub(newIntent)
        super.onNewIntent(newIntent)
        setIntent(newIntent)

        // Warm start path: engine is alive, channel ready — call your handler
        if (pendingFileIntent != null) {
            handleSharedFile(pendingFileIntent)
            pendingFileIntent = null
        } else {
            handleSharedFile(newIntent) // fallback (e.g., SEND with no data scrubbed)
        }
    }

    private fun handleSharedFile(intent: Intent?) {
        Log.d("RingDrillShare", "handleSharedFile() intent=$intent")
        if (intent == null) return

        Log.d("RingDrillShare", "action=${intent.action} type=${intent.type} " +
                "hasExtra=${intent.hasExtra(Intent.EXTRA_STREAM)} " +
                "clipDataCount=${intent.clipData?.itemCount ?: 0} data=${intent.data}")

        // 0) A "Share" from Messenger/Chrome/etc. on a ringdrill.app link (e.g.
        // the Web Share API call on the catalog page, or "Share" on a chat
        // link) arrives as ACTION_SEND with the URL in EXTRA_TEXT, not as a
        // file stream. Route it to Flutter as a link so the normal /i/<slug>
        // install flow runs. Without this, execution fell through to the
        // EXTRA_STREAM/clipData handling below, which would pick up whatever
        // unrelated content:// URI the sharing app happened to attach (e.g. a
        // link-preview thumbnail) and copy it into a bogus "shared.drill".
        if (intent.action == Intent.ACTION_SEND && !intent.hasExtra(Intent.EXTRA_STREAM)) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            val link = extractRingDrillLink(text)
            if (link != null) {
                Log.d("RingDrillShare", "Resolved shared link: $link")
                methodChannel.invokeMethod("onSharedLink", link)
                return
            }
            if ((intent.type ?: "").startsWith("text/")) {
                Log.w("RingDrillShare", "Text share with no RingDrill link, ignoring: $text")
                return
            }
        }

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
        val filename = getFileNameFromUri(contentResolver, uri)
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

                    // Guard against copying something that isn't actually a
                    // .drill archive (e.g. a stray content:// URI the sender
                    // attached alongside shared text). Fail fast here with a
                    // clear error instead of handing Flutter a file named
                    // "shared.drill" that will only fail deep inside the ZIP
                    // parser with a confusing message.
                    if (!looksLikeZip(tempFile)) {
                        Log.w("RingDrillShare", "Copied content is not a ZIP, ignoring: ${tempFile.absolutePath}")
                        tempFile.delete()
                        methodChannel.invokeMethod("onSharedFileError", "Not a valid .drill file")
                        return
                    }

                    methodChannel.invokeMethod("onSharedFilePath", tempFile.absolutePath)
                    Log.d("RingDrillShare", "Sent to Flutter: ${tempFile.absolutePath}")
                }
                "file" -> {
                    val file = uri.toFile()
                    if (!looksLikeZip(file)) {
                        Log.w("RingDrillShare", "File is not a ZIP, ignoring: ${file.absolutePath}")
                        methodChannel.invokeMethod("onSharedFileError", "Not a valid .drill file")
                        return
                    }
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

    // Pull a ringdrill.app /i/ or /o/ link out of shared text (Web Share API,
    // "Share" on a chat link, etc). /d/ is excluded: it is the raw-download
    // alias and has no corresponding in-app route.
    private fun extractRingDrillLink(text: String?): String? {
        if (text.isNullOrBlank()) return null
        val match = Regex("""https://ringdrill\.app/(?:i|o)/\S+""").find(text) ?: return null
        return match.value.trimEnd('.', ',', ')', ']', '"', '\'')
    }

    // Cheap magic-byte sniff: every ZIP (and therefore every .drill archive)
    // starts with the "PK" signature. Catches junk copied from an unrelated
    // content:// URI before it reaches Flutter's ZIP parser.
    private fun looksLikeZip(file: File): Boolean {
        return try {
            file.inputStream().use { ins ->
                val header = ByteArray(2)
                ins.read(header) == 2 && header[0] == 0x50.toByte() && header[1] == 0x4B.toByte()
            }
        } catch (e: Exception) {
            false
        }
    }

    // Helper: copy the intent (to keep data), then scrub the Activity intent
    private fun captureAndScrub(src: Intent?) {
        if (src?.action == Intent.ACTION_VIEW) {
            val scheme = src.data?.scheme
            if (scheme == "content" || scheme == "file") {
                // Make a copy we will process later with your unchanged handler
                if (pendingFileIntent == null) {
                    pendingFileIntent = Intent(src) // shallow copy keeps data/clipData/type
                }
                // Scrub so Flutter/go_router doesn’t treat it as an initial route
                src.data = null
                src.clipData = null
            }
        } else if (src?.action == Intent.ACTION_SEND) {
            // ACTION_SEND has no `data` to scrub, but still needs to be
            // stashed: configureFlutterEngine()'s cold-start branch only
            // calls handleSharedFile() when pendingFileIntent is non-null.
            // Without this, a cold-started app (process killed, then
            // relaunched by tapping a shared link/file) never processes the
            // share at all — the app opens, but the content is dropped.
            if (pendingFileIntent == null) {
                pendingFileIntent = Intent(src)
            }
        }
    }

    private fun getFileNameFromUri(contentResolver: ContentResolver, uri: Uri): String {
        // Verify if the URI is a content URI
        if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )
            cursor?.use {
                if (it.moveToFirst()) {
                    val columnIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (columnIndex != -1) {
                        return it.getString(columnIndex)
                    }
                }
            }
        }

        // Fallback to #selection content you already provided
        return uri.lastPathSegment?.substringAfterLast('/') ?: "shared.drill"
    }

}
