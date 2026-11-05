import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class NativeFileService {
  static const MethodChannel _channel =
      MethodChannel('com.smartworkshop/native_bridge');

  /// يفتح مدير الملفات الرسمي في الأندرويد (Storage Access Framework) ليختار المستخدم مكان واسم حفظ ملف الـ PDF
  static Future<String?> savePdfWithFilePicker({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final cleanName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    if (Platform.isAndroid) {
      try {
        final String? uriStr = await _channel.invokeMethod<String>(
          'saveFileWithPicker',
          {
            'fileName': cleanName,
            'bytes': bytes,
          },
        );
        if (uriStr != null && uriStr.isNotEmpty) {
          return uriStr;
        }
        return null;
      } catch (_) {
        // في حالة عدم توفر الـ Channel نلجأ للحفظ المباشر في التنزيلات
        return savePdfToDownloadsDirect(fileName: cleanName, bytes: bytes);
      }
    }
    return savePdfToDownloadsDirect(fileName: cleanName, bytes: bytes);
  }

  /// يحفظ نسخة مباشرة داخل مجلد التنزيلات (Downloads) عبر MediaStore بدون أخطاء صلاحيات أندرويد 11+
  static Future<String> savePdfToDownloadsDirect({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final cleanName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    if (Platform.isAndroid) {
      try {
        final String? savedPath = await _channel.invokeMethod<String>(
          'saveToDownloads',
          {
            'fileName': cleanName,
            'bytes': bytes,
          },
        );
        if (savedPath != null && savedPath.isNotEmpty) {
          return savedPath;
        }
      } catch (_) {}

      try {
        final dl = Directory('/storage/emulated/0/Download');
        if (await dl.exists()) {
          final f = File('${dl.path}/$cleanName');
          await f.writeAsBytes(bytes, flush: true);
          return f.path;
        }
      } catch (_) {}
    }

    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$cleanName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// حفظ مؤقت للمشاركة عبر تطبيقات التواصل
  static Future<File> saveTempPdfForShare({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final cleanName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$cleanName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// فتح رابط كتالوج خارجي في المتصفح أو جوجل درايف
  static Future<bool> openExternalUrl(String url) async {
    if (url.trim().isEmpty) return false;
    if (Platform.isAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>(
          'openExternalUrl',
          {'url': url.trim()},
        );
        return ok ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }
}
