import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// أداة تحميل وعرض رسومات مقاطع القطاعات الهندسية (SVG المضمن بـ Base64 PNG)
class SvgProfileLoader {
  static final Map<String, Uint8List> _cache = {};
  static final RegExp _b64Regex =
      RegExp(r'data:image/png;base64,([A-Za-z0-9+/=\s]+)');

  static Future<Uint8List?> loadPngBytes(String? assetPath) async {
    if (assetPath == null || assetPath.isEmpty) return null;
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath];
    }

    try {
      if (assetPath.endsWith('.png') || assetPath.endsWith('.jpg') || assetPath.endsWith('.webp')) {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        _cache[assetPath] = bytes;
        return bytes;
      }

      final svgStr = await rootBundle.loadString(assetPath);
      final match = _b64Regex.firstMatch(svgStr);
      if (match != null) {
        final cleanB64 = match.group(1)!.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleanB64);
        _cache[assetPath] = bytes;
        return bytes;
      }
    } catch (_) {}
    return null;
  }
}

class SvgProfileWidget extends StatelessWidget {
  final String? assetPath;
  final double width;
  final double height;
  final BoxFit fit;

  const SvgProfileWidget({
    super.key,
    required this.assetPath,
    this.width = 56,
    this.height = 56,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath == null || assetPath!.isEmpty) {
      return _fallbackBox();
    }

    if (assetPath!.endsWith('.png') ||
        assetPath!.endsWith('.jpg') ||
        assetPath!.endsWith('.webp')) {
      return Image.asset(
        assetPath!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallbackBox(),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: SvgProfileLoader.loadPngBytes(assetPath),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
          );
        }
        return _fallbackBox();
      },
    );
  }

  Widget _fallbackBox() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Icon(
        Icons.architecture,
        size: width * 0.5,
        color: const Color(0xFF475569),
      ),
    );
  }
}
