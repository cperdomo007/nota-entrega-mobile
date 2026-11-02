package com.notaentrega.nota_entrega_mobile

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.net.Uri
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/** Local OCR only: documents are never uploaded or put in the shared gallery. */
class RifScanner(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "nota_entrega/rif_scanner")
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "camera" && call.method != "file") {
                result.notImplemented()
            } else if (pending != null) {
                result.error("SCAN_BUSY", "Ya hay una lectura en curso.", null)
            } else {
                pending = result
                try {
                    if (call.method == "camera") scan() else pick()
                } catch (_: Exception) {
                    fail("SCAN_UNAVAILABLE")
                }
            }
        }
    }

    private fun scan() {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(1)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                if (pending != null && !activity.isDestroyed) {
                    try {
                        activity.startIntentSenderForResult(sender, CAMERA, null, 0, 0, 0)
                    } catch (_: Exception) {
                        fail("SCAN_UNAVAILABLE")
                    }
                }
            }
            .addOnFailureListener { fail("SCAN_UNAVAILABLE") }
    }

    private fun pick() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "image/*"))
        }
        activity.startActivityForResult(intent, FILE)
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?) {
        if (request != CAMERA && request != FILE) return
        if (pending == null) return
        if (code != Activity.RESULT_OK) {
            complete(null)
            return
        }
        val uri = if (request == CAMERA) {
            GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages?.firstOrNull()?.imageUri
        } else data?.data
        if (uri == null) {
            fail("SCAN_READ_FAILED")
            return
        }
        executor.execute { recognize(uri) }
    }

    private fun recognize(uri: Uri) {
        var temporary: File? = null
        var bitmap: Bitmap? = null
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            temporary = File.createTempFile("rif-", ".input", activity.cacheDir)
            activity.contentResolver.openInputStream(uri)!!.use { input ->
                temporary.outputStream().use { output ->
                    val buffer = ByteArray(8192)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        require(total <= 20L * 1024 * 1024) { "FILE_TOO_LARGE" }
                        output.write(buffer, 0, count)
                    }
                }
            }
            val isPdf = temporary.inputStream().use { input ->
                val header = ByteArray(5)
                input.read(header) == 5 && String(header, Charsets.US_ASCII) == "%PDF-"
            }
            val working = if (isPdf) renderPdf(temporary) else readImage(temporary)
            bitmap = working
            // Only wait on this worker; never block Android's UI thread.
            val text = Tasks.await(recognizer.process(InputImage.fromBitmap(working, 0)))
            // SENIAT puts registry dates in a right-hand column. Read the left
            // contributor column, grouping adjacent words on the same baseline.
            val lines = text.textBlocks.flatMap { it.lines }
                .filter { (it.boundingBox?.left ?: 0) < working.width * 0.60 }
                .sortedBy { it.boundingBox?.centerY() ?: 0 }
            val rows = mutableListOf<MutableList<com.google.mlkit.vision.text.Text.Line>>()
            for (line in lines) {
                val previous = rows.lastOrNull()?.firstOrNull()?.boundingBox
                val box = line.boundingBox
                if (previous != null && box != null &&
                    kotlin.math.abs(previous.centerY() - box.centerY()) <=
                    kotlin.math.min(previous.height(), box.height()) * 0.5) {
                    rows.last().add(line)
                } else rows.add(mutableListOf(line))
            }
            val output = rows.joinToString("\n") { row ->
                row.sortedBy { it.boundingBox?.left ?: 0 }.joinToString(" ") { it.text }
            }
            activity.runOnUiThread { complete(output) }
        } catch (failure: Exception) {
            val error = if (failure.message == "FILE_TOO_LARGE") "FILE_TOO_LARGE" else "SCAN_READ_FAILED"
            activity.runOnUiThread { fail(error) }
        } finally {
            recognizer.close()
            bitmap?.recycle()
            temporary?.delete()
        }
    }

    private fun renderPdf(file: File): Bitmap {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                require(renderer.pageCount > 0)
                renderer.openPage(0).use { page ->
                    val scale = 3000.0 / max(page.width, page.height)
                    val bitmap = Bitmap.createBitmap(
                        max(1, (page.width * scale).roundToInt()),
                        max(1, (page.height * scale).roundToInt()), Bitmap.Config.ARGB_8888)
                    try {
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        return bitmap
                    } catch (failure: Exception) {
                        bitmap.recycle()
                        throw failure
                    }
                }
            }
        }
    }

    private fun readImage(file: File): Bitmap {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, options)
        require(options.outWidth > 0 && options.outHeight > 0)
        options.inSampleSize = 1
        while (max(options.outWidth, options.outHeight) / options.inSampleSize > 3000) {
            options.inSampleSize *= 2
        }
        options.inJustDecodeBounds = false
        val original = requireNotNull(BitmapFactory.decodeFile(file.path, options))
        val orientation = try {
            ExifInterface(file.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
        } catch (_: Exception) { 1 }
        val matrix = Matrix()
        when (orientation) {
            2 -> matrix.setScale(-1f, 1f)
            3 -> matrix.setRotate(180f)
            4 -> matrix.setScale(1f, -1f)
            5 -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
            6 -> matrix.setRotate(90f)
            7 -> { matrix.setRotate(270f); matrix.postScale(-1f, 1f) }
            8 -> matrix.setRotate(270f)
        }
        if (matrix.isIdentity) return original
        return try {
            Bitmap.createBitmap(original, 0, 0, original.width, original.height, matrix, true)
        } finally { original.recycle() }
    }

    private fun complete(text: String?) {
        pending?.success(text)
        pending = null
    }

    private fun fail(code: String) {
        pending?.error(code, "No se pudo leer el documento.", null)
        pending = null
    }

    fun close() {
        channel.setMethodCallHandler(null)
        fail("SCAN_INTERRUPTED")
        executor.shutdown()
    }

    companion object {
        private const val CAMERA = 6201
        private const val FILE = 6202
    }
}
