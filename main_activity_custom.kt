package com.smartworkshop.smart_workshop

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smartworkshop/native_bridge"
    private val CREATE_PDF_REQUEST_CODE = 9021

    private var pendingBytes: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFileWithPicker" -> {
                    val fileName = call.argument<String>("fileName") ?: "Hafez_Document.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("NO_BYTES", "لا توجد بيانات لحفظ الملف", null)
                        return@setMethodCallHandler
                    }
                    pendingBytes = bytes
                    pendingResult = result

                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    try {
                        startActivityForResult(intent, CREATE_PDF_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingBytes = null
                        pendingResult = null
                        result.error("PICKER_ERROR", e.localizedMessage, null)
                    }
                }
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "Hafez_Document.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("NO_BYTES", "لا توجد بيانات", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedPath = saveBytesToDownloads(fileName, bytes)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.localizedMessage, null)
                    }
                }
                "openExternalUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isNotEmpty()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("URL_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveBytesToDownloads(fileName: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("تعذر إنشاء الملف في مجلد التنزيلات")
            resolver.openOutputStream(uri)?.use { out ->
                out.write(bytes)
                out.flush()
            }
            return "Download/$fileName"
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            FileOutputStream(file).use { out ->
                out.write(bytes)
                out.flush()
            }
            return file.absolutePath
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CREATE_PDF_REQUEST_CODE) {
            val res = pendingResult
            val bytes = pendingBytes
            pendingResult = null
            pendingBytes = null

            if (resultCode == Activity.RESULT_OK && data?.data != null && bytes != null) {
                val uri: Uri = data.data!!
                try {
                    contentResolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(bytes)
                        outputStream.flush()
                    }
                    res?.success(uri.toString())
                } catch (e: Exception) {
                    res?.error("WRITE_ERROR", e.localizedMessage, null)
                }
            } else {
                res?.success(null) // ألغى المستخدم الاختيار
            }
        }
    }
}
