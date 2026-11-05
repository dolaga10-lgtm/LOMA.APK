import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workshop_models.dart';
import '../widgets/svg_profile_widget.dart';
import '../widgets/window_2d_visualizer.dart';
import 'native_file_service.dart';
import 'workshop_storage.dart';

class PdfGeneratorService {
  static ui.Image? _hafezLogoUiImage;

  static Future<ui.Image?> _loadUiImageFromAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> _loadUiImageFromBytes(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ensureLogoLoaded() async {
    _hafezLogoUiImage ??=
        await _loadUiImageFromAsset('assets/images/hafez_logo.png') ??
            await _loadUiImageFromAsset('assets/images/hafez_icon.png');
  }

  static String formatMoney(double val) {
    final int intVal = val.round();
    final String s = intVal.toString();
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write(',');
      }
      sb.write(s[i]);
    }
    return sb.toString();
  }

  static void _drawTextInRect(
    Canvas canvas,
    Rect rect,
    String text, {
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    TextAlign textAlign = TextAlign.center,
    TextDirection textDirection = TextDirection.rtl,
    int? maxLines,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.18,
        ),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
    )..layout(maxWidth: math.max(10.0, rect.width - 6));

    double dx = rect.left + (rect.width - tp.width) / 2;
    if (textAlign == TextAlign.right) {
      dx = rect.right - tp.width - 6;
    } else if (textAlign == TextAlign.left) {
      dx = rect.left + 6;
    }
    final double dy = rect.top + (rect.height - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  /// توليد صور صفحات عرض السعر (للاستعراض المسبق وللتصدير كـ PDF)
  static Future<List<Uint8List>> renderQuotationPagesPngList({
    required ClientRecord client,
    required WorkshopStorage storage,
  }) async {
    await _ensureLogoLoaded();
    final bool minOneM2 =
        storage.pricingSettings.enforceMinimumOneSquareMeter;
    final settings = storage.pricingSettings;

    double totalAreaAll = 0.0;
    int totalQuantityAll = 0;
    double grandTotalAll = 0.0;
    double itemsArchTotal = 0.0;

    for (final it in client.items) {
      final double dispArea = it.displayTotalAreaM2(minOneM2: minOneM2);
      final double cost = it.calculateTotalCost(
          storage.getSectorById(it.sectorId),
          minOneM2: minOneM2);
      totalAreaAll += dispArea;
      totalQuantityAll += it.quantity;
      grandTotalAll += cost;
      itemsArchTotal += it.calculateArchTotalCost();
    }

    final double netTotal =
        (grandTotalAll - client.discountAmount).clamp(0.0, double.infinity);
    final double finalQuotationTotal =
        (netTotal + client.archCost - client.depositAmount)
            .clamp(0.0, double.infinity);
    final double totalDisplayedArchCost = itemsArchTotal + client.archCost;

    const int itemsPerPage = 6;
    final int totalPages =
        math.max(1, (client.items.length / itemsPerPage).ceil());
    final List<Uint8List> pages = [];

    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final int startIdx = pageIdx * itemsPerPage;
      final int endIdx =
          math.min(client.items.length, startIdx + itemsPerPage);
      final pageItems = client.items.isEmpty
          ? <ClientWindowItem>[]
          : client.items.sublist(startIdx, endIdx);
      final bool isLastPage = (pageIdx == totalPages - 1);

      final Uint8List pagePng = await _renderQuotationPagePng(
        client: client,
        storage: storage,
        settings: settings,
        pageItems: pageItems,
        startIndex: startIdx,
        minOneM2: minOneM2,
        totalQuantityAll: totalQuantityAll,
        totalAreaAll: totalAreaAll,
        grandTotalAll: grandTotalAll,
        totalDisplayedArchCost: totalDisplayedArchCost,
        finalQuotationTotal: finalQuotationTotal,
        showFooterSummary: isLastPage,
      );
      pages.add(pagePng);
    }
    return pages;
  }

  /// 1. توليد كشف عرض السعر المعماري المطابق 100% لملف (أ. احمد ابو اليزيد.pdf) مع رسم الدوران والأبواب والباندا
  static Future<Uint8List> buildQuotationPdfBytes({
    required ClientRecord client,
    required WorkshopStorage storage,
  }) async {
    final pdf = pw.Document();
    final pagesPng = await renderQuotationPagesPngList(
      client: client,
      storage: storage,
    );

    for (final pagePng in pagesPng) {
      final pageImg = pw.MemoryImage(pagePng);
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(792, 612), // Landscape
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pageImg, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    return pdf.save();
  }

  static Future<Uint8List> _renderQuotationPagePng({
    required ClientRecord client,
    required WorkshopStorage storage,
    required PricingSettings settings,
    required List<ClientWindowItem> pageItems,
    required int startIndex,
    required bool minOneM2,
    required int totalQuantityAll,
    required double totalAreaAll,
    required double grandTotalAll,
    required double totalDisplayedArchCost,
    required double finalQuotationTotal,
    required bool showFooterSummary,
  }) async {
    const double canvasW = 1650.0;
    const double canvasH = 1275.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasW, canvasH));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()..color = Colors.white,
    );

    const Color tealHeader = Color(0xFF388E9C);
    const Color summaryBlue = Color(0xFF558ED5);
    const double tableLeft = 175.0;
    const double tableWidth = 1300.0;
    const double tableRight = tableLeft + tableWidth;

    // ==================== 1. البانر الأسود العلوي مع لوجو شركة الحافظ ====================
    const double bannerTop = 28.0;
    const double bannerHeight = 122.0;
    final Rect blackBanner =
        Rect.fromLTWH(tableLeft, bannerTop, tableWidth, bannerHeight);
    canvas.drawRect(blackBanner, Paint()..color = Colors.black);

    final Rect rightClientBox =
        Rect.fromLTWH(tableRight - 430, bannerTop + 44, 418, 46);
    canvas.drawRect(rightClientBox, Paint()..color = tealHeader);
    canvas.drawLine(
      Offset(rightClientBox.right - 140, rightClientBox.top),
      Offset(rightClientBox.right - 140, rightClientBox.bottom),
      Paint()
        ..color = Colors.black54
        ..strokeWidth = 1.2,
    );
    _drawTextInRect(
      canvas,
      Rect.fromLTWH(rightClientBox.right - 140, rightClientBox.top, 140,
          rightClientBox.height),
      'أسم العميل /',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF0F172A),
    );
    _drawTextInRect(
      canvas,
      Rect.fromLTWH(rightClientBox.left, rightClientBox.top,
          rightClientBox.width - 140, rightClientBox.height),
      client.clientName.isNotEmpty ? client.clientName : 'أ. احمد ابو اليزيد',
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF0F172A),
    );

    final Rect leftLocBox =
        Rect.fromLTWH(tableLeft + 12, bannerTop + 44, 330, 46);
    canvas.drawRect(leftLocBox, Paint()..color = tealHeader);
    canvas.drawLine(
      Offset(leftLocBox.right - 105, leftLocBox.top),
      Offset(leftLocBox.right - 105, leftLocBox.bottom),
      Paint()
        ..color = Colors.black54
        ..strokeWidth = 1.2,
    );
    _drawTextInRect(
      canvas,
      Rect.fromLTWH(
          leftLocBox.right - 105, leftLocBox.top, 105, leftLocBox.height),
      'المكان /',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF0F172A),
    );
    _drawTextInRect(
      canvas,
      Rect.fromLTWH(leftLocBox.left, leftLocBox.top, leftLocBox.width - 105,
          leftLocBox.height),
      client.clientAddress.isNotEmpty
          ? client.clientAddress
          : 'ابراج الروضه شارع ناصر',
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF0F172A),
    );

    if (_hafezLogoUiImage != null) {
      final Rect logoDst = Rect.fromCenter(
        center: Offset(blackBanner.center.dx - 35, blackBanner.center.dy),
        width: 118,
        height: 114,
      );
      paintImage(
        canvas: canvas,
        rect: logoDst,
        image: _hafezLogoUiImage!,
        fit: BoxFit.contain,
      );
    }

    // ==================== 2. جدول عرض السعر ذو الـ 13 عموداً (من اليمين لليسار) ====================
    final List<double> colWidths = [
      34,  // No.
      146, // رسومات
      82,  // عرض
      82,  // طول
      84,  // متر مربع
      138, // توصيف
      80,  // لون القطاع
      95,  // نوع الزجاج
      96,  // سعر المتر
      108, // سعر الوحدة
      76,  // عدد
      115, // اجمالي المتر المربع
      164, // اجمالي السعر
    ];

    final List<String> colHeaders = [
      'No.',
      'رسومات',
      'عرض',
      'طول',
      'متر مربع',
      'توصيف',
      'لون القطاع',
      'نوع\nالزجاج',
      'سعر المتر',
      'سعر الوحدة',
      'عدد',
      'اجمالي المتر\nالمربع',
      'اجمالي السعر',
    ];

    final List<Rect> colHeaderRects = [];
    double curRight = tableRight;
    const double headerRowTop = bannerTop + bannerHeight;
    const double headerRowHeight = 46.0;

    for (int c = 0; c < colWidths.length; c++) {
      final double w = colWidths[c];
      final Rect r =
          Rect.fromLTWH(curRight - w, headerRowTop, w, headerRowHeight);
      colHeaderRects.add(r);
      curRight -= w;
    }

    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (int c = 0; c < colHeaderRects.length; c++) {
      final Rect r = colHeaderRects[c];
      canvas.drawRect(r, Paint()..color = tealHeader);
      canvas.drawRect(r, borderPaint);
      _drawTextInRect(
        canvas,
        r,
        colHeaders[c],
        fontSize: c == 0 ? 13 : 15,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0F172A),
      );
    }

    double curRowTop = headerRowTop + headerRowHeight;
    const double rowHeight = 114.0;

    for (int i = 0; i < pageItems.length; i++) {
      final item = pageItems[i];
      final sector = storage.getSectorById(item.sectorId);
      final double singleArea = item.displaySingleAreaM2(minOneM2: minOneM2);
      final double totalArea = item.displayTotalAreaM2(minOneM2: minOneM2);
      final double rowTotal =
          item.calculateTotalCost(sector, minOneM2: minOneM2);
      final double unitPrice =
          item.quantity > 0 ? (rowTotal / item.quantity) : rowTotal;
      final double meterPrice = item.effectiveMeterPrice(sector);

      final List<String> rowValues = [
        'W${startIndex + i + 1}',
        '', // رسومات
        '${item.widthCm.toStringAsFixed(0)} cm',
        '${item.heightCm.toStringAsFixed(0)} cm',
        singleArea.toStringAsFixed(2),
        item.pdfDescriptionText(sector),
        item.sectorColor,
        item.glassSummaryText,
        meterPrice.toStringAsFixed(0),
        formatMoney(unitPrice),
        '${item.quantity}',
        totalArea.toStringAsFixed(2),
        formatMoney(rowTotal),
      ];

      for (int c = 0; c < colWidths.length; c++) {
        final Rect headerR = colHeaderRects[c];
        final Rect cellR =
            Rect.fromLTWH(headerR.left, curRowTop, headerR.width, rowHeight);

        if (c == 0) {
          canvas.drawRect(cellR, Paint()..color = tealHeader);
        } else {
          canvas.drawRect(cellR, Paint()..color = Colors.white);
        }
        canvas.drawRect(cellR, borderPaint);

        if (c == 1) {
          // رسم الشباك بنفس شكله وثوابته والباندا والشفاط والدوران والأبواب داخل خلية "رسومات"
          canvas.save();
          final Rect drawArea = cellR.deflate(8);
          canvas.translate(drawArea.left, drawArea.top);
          final painter = RealisticWindowPainter(
            widthCm: item.widthCm,
            heightCm: item.heightCm,
            unitType: item.unitType,
            openType: item.openType,
            sashCount: item.sashCount,
            barType: item.barType,
            openDirection: item.openDirection,
            sectorColor: item.sectorColor,
            hasArch: item.hasArch,
            archWidthCm: item.archWidthCm,
            archHeightCm: item.archHeightCm,
            hasDoorKickplate: item.hasDoorKickplate,
            doorBottomKickHeightCm: item.doorBottomKickHeightCm,
            hasDoorMiddleMullion: item.hasDoorMiddleMullion,
            doorBottomPanelType: item.doorBottomPanelType,
            hasTopFixed: item.hasTopFixed,
            topFixedHeightCm: item.topFixedHeightCm,
            topFixedSplits: item.topFixedSplits,
            hasBottomFixed: item.hasBottomFixed,
            bottomFixedHeightCm: item.bottomFixedHeightCm,
            bottomFixedSplits: item.bottomFixedSplits,
            hasRightFixed: item.hasRightFixed,
            rightFixedWidthCm: item.rightFixedWidthCm,
            rightFixedSplits: item.rightFixedSplits,
            hasLeftFixed: item.hasLeftFixed,
            leftFixedWidthCm: item.leftFixedWidthCm,
            leftFixedSplits: item.leftFixedSplits,
            hasExhaustFan: item.hasExhaustFan,
            exhaustFanShape: item.exhaustFanShape,
            exhaustFanDiameterCm: item.exhaustFanDiameterCm,
            exhaustFanPosition: item.exhaustFanPosition,
            exhaustFanPartIndex: item.exhaustFanPartIndex,
            isExhaustFanFitOptimal: item.isExhaustFanSizeOptimal(
                fixedDeductCm: sector?.fixedGlassDeductCm ?? 6.4),
            hasGlass: item.hasGlass,
            isDoubleGlass: item.isDoubleGlass,
            hasGeorgian: item.hasGeorgianBars,
            hasFlyScreen: item.hasFlyScreen,
            hasPanda: item.hasPanda,
            isCompact: true,
          );
          painter.paint(canvas, drawArea.size);
          canvas.restore();
        } else {
          _drawTextInRect(
            canvas,
            cellR,
            rowValues[c],
            fontSize: c == 0 ? 13 : (c == 5 || c == 7 ? 13.5 : 17.5),
            fontWeight: FontWeight.bold,
            color: Colors.black,
            textDirection: (c == 2 || c == 3 || c == 4 || c >= 8)
                ? TextDirection.ltr
                : TextDirection.rtl,
          );
        }
      }

      curRowTop += rowHeight;
    }

    // ==================== 3. صف إجماليات الجدول السفلي ====================
    const double totalRowH = 42.0;
    for (int c = 0; c < colWidths.length; c++) {
      final Rect headerR = colHeaderRects[c];
      final Rect cellR =
          Rect.fromLTWH(headerR.left, curRowTop, headerR.width, totalRowH);
      canvas.drawRect(cellR, Paint()..color = tealHeader);
      canvas.drawRect(cellR, borderPaint);

      if (c == 10) {
        _drawTextInRect(
          canvas,
          cellR,
          '$totalQuantityAll',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          textDirection: TextDirection.ltr,
        );
      } else if (c == 11) {
        _drawTextInRect(
          canvas,
          cellR,
          '${totalAreaAll.toStringAsFixed(2)} m2',
          fontSize: 15,
          fontWeight: FontWeight.bold,
          textDirection: TextDirection.ltr,
        );
      } else if (c == 12) {
        _drawTextInRect(
          canvas,
          cellR,
          '${formatMoney(grandTotalAll)} EGP',
          fontSize: 15.5,
          fontWeight: FontWeight.bold,
          textDirection: TextDirection.ltr,
        );
      }
    }
    curRowTop += totalRowH;

    // ==================== 4. الفوتر وملخص المقايسة وشروط التعاقد ====================
    if (showFooterSummary) {
      _drawTextInRect(
        canvas,
        Rect.fromLTWH(tableLeft, curRowTop + 4, tableWidth, 26),
        'وتفضلو بقبول فائق الاحترام,,,',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      );

      const double sumBoxW = 590.0;
      const double sumRowH = 34.0;
      final double sumLeft = tableLeft + 465.0;
      final double sumTop = curRowTop + 32.0;

      final List<Map<String, String>> sumRows = [
        {
          'label': 'يضاف للمقايسة قيمة : عربون',
          'val': client.depositAmount > 0
              ? '${formatMoney(client.depositAmount)} EGP'
              : '',
        },
        {
          'label': 'يضاف للمقايسة قيمة :دورانات',
          'val': totalDisplayedArchCost > 0
              ? '${formatMoney(totalDisplayedArchCost)} EGP'
              : '',
        },
        {
          'label': 'إجمالى المقايسة',
          'val': '${formatMoney(finalQuotationTotal)} EGP',
        },
      ];

      for (int r = 0; r < sumRows.length; r++) {
        final double ry = sumTop + r * sumRowH;
        final Rect valCell = Rect.fromLTWH(sumLeft, ry, 165, sumRowH);
        final Rect lblCell =
            Rect.fromLTWH(sumLeft + 165, ry, sumBoxW - 165, sumRowH);

        canvas.drawRect(valCell, Paint()..color = summaryBlue);
        canvas.drawRect(lblCell, Paint()..color = summaryBlue);
        canvas.drawRect(valCell, borderPaint);
        canvas.drawRect(lblCell, borderPaint);

        _drawTextInRect(
          canvas,
          valCell,
          sumRows[r]['val']!,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          textDirection: TextDirection.ltr,
        );
        _drawTextInRect(
          canvas,
          lblCell,
          sumRows[r]['label']!,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        );
      }

      double noteY = sumTop + (sumRowH * 3) + 10.0;
      final List<String> footerLines = [
        settings.pdfNoteLine1,
        settings.pdfNoteLine2,
        settings.pdfNoteLine3,
        settings.pdfNoteLine4,
        '${settings.pdfNoteLine5}  •  ${settings.pdfNoteLine6}',
        'شروط التعاقد : ${settings.termsAndConditions}',
      ];

      for (int n = 0; n < footerLines.length; n++) {
        _drawTextInRect(
          canvas,
          Rect.fromLTWH(tableLeft, noteY, tableWidth, 26),
          footerLines[n],
          fontSize: n == 0 ? 20 : 16.5,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        );
        noteY += 25.0;
      }
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(canvasW.toInt(), canvasH.toInt());
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// توليد صور صفحات كشف حساب الطلبية وتقطيع الأعواد والزجاج والإكسسوارات والدورانات (للاستعراض المسبق وللتصدير كـ PDF)
  static Future<List<Uint8List>> renderOrderCalculationPagesPngList({
    required ClientRecord client,
    required WorkshopStorage storage,
  }) async {
    await _ensureLogoLoaded();
    final aggregatedProfiles =
        storage.calculateAggregatedProfilesOrder(client.items);
    final calculatedAccessories =
        storage.calculateAccessoriesOrder(client.items);
    final archReports = storage.buildArchReportList(client.items);

    final List<GlassCutPiece> allGlassPieces = [];
    for (final item in client.items) {
      if (!item.hasGlass) continue;
      final sec =
          storage.getSectorById(item.sectorId) ?? storage.sectors.first;
      allGlassPieces.addAll(sec.buildWindowGlassCutList(item));
    }

    final Map<String, ui.Image?> profileImages = {};
    for (final prof in aggregatedProfiles) {
      if (prof.svgAssetPath != null &&
          !profileImages.containsKey(prof.svgAssetPath)) {
        final bytes = await SvgProfileLoader.loadPngBytes(prof.svgAssetPath);
        profileImages[prof.svgAssetPath!] = await _loadUiImageFromBytes(bytes);
      }
    }

    final List<Uint8List> pages = [];

    // الصفحة الأولى: كشف القطاعات المجمعة (الدرفة طول+عرض في بند واحد + قطاع إتش والبار) + كشف مقاسات الزجاج الصافية (للضلف والثوابت)
    final page1Png = await _renderOrderPage1ProfilesAndGlassPng(
      client: client,
      storage: storage,
      aggregatedProfiles: aggregatedProfiles,
      allGlassPieces: allGlassPieces,
      profileImages: profileImages,
    );
    pages.add(page1Png);

    // الصفحة الثانية: كشف الإكسسوارات الكامل (رينو، عضم، ميجا، تراك، مانع ارتجاج، عجل، مقابض...) + بيان مقاسات الدورانات للإبلاغ فقط دون تضليع
    if (calculatedAccessories.isNotEmpty || archReports.isNotEmpty) {
      final page2Png = await _renderOrderPage2AccessoriesAndArchesPng(
        client: client,
        storage: storage,
        calculatedAccessories: calculatedAccessories,
        archReports: archReports,
      );
      pages.add(page2Png);
    }

    return pages;
  }

  /// 2. توليد كشف حساب الطلبية وتقطيع الأعواد والزجاج والإكسسوارات والدورانات كملف PDF
  static Future<Uint8List> buildCuttingListPdfBytes({
    required ClientRecord client,
    required WorkshopStorage storage,
  }) async {
    final pdf = pw.Document();
    final pagesPng = await renderOrderCalculationPagesPngList(
      client: client,
      storage: storage,
    );

    for (final pagePng in pagesPng) {
      final orderImg = pw.MemoryImage(pagePng);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(orderImg, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    return pdf.save();
  }

  static Future<Uint8List> _renderOrderPage1ProfilesAndGlassPng({
    required ClientRecord client,
    required WorkshopStorage storage,
    required List<AggregatedProfileOrder> aggregatedProfiles,
    required List<GlassCutPiece> allGlassPieces,
    required Map<String, ui.Image?> profileImages,
  }) async {
    const double canvasW = 1240.0;
    const double canvasH = 1754.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasW, canvasH));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()..color = Colors.white,
    );

    const Color tealHeader = Color(0xFF1E293B);

    const Rect headerBox = Rect.fromLTWH(40, 30, canvasW - 80, 90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headerBox, const Radius.circular(10)),
      Paint()..color = tealHeader,
    );

    if (_hafezLogoUiImage != null) {
      paintImage(
        canvas: canvas,
        rect: const Rect.fromLTWH(60, 40, 70, 70),
        image: _hafezLogoUiImage!,
        fit: BoxFit.contain,
      );
    }

    _drawTextInRect(
      canvas,
      const Rect.fromLTWH(150, 38, canvasW - 210, 40),
      'كشف حساب الطلبية وتقطيع الأعواد والزجاج (صفحة 1: القطاعات والزجاج) — شركة الحافظ',
      fontSize: 20.5,
      fontWeight: FontWeight.bold,
      color: const Color(0xFFFDE68A),
      textAlign: TextAlign.right,
    );
    _drawTextInRect(
      canvas,
      const Rect.fromLTWH(150, 76, canvasW - 210, 34),
      'العميل: ${client.clientName}   |   العنوان: ${client.clientAddress}   |   عدد البنود: ${client.items.length}',
      fontSize: 16.5,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      textAlign: TextAlign.right,
    );

    double curY = 132.0;
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final int glassRowCount = math.max(1, allGlassPieces.length);
    final double reservedForGlass =
        math.min(600.0, 90.0 + (glassRowCount * 35.0));
    final double maxProfilesEndY = canvasH - reservedForGlass - 26.0;

    // أولاً: جدول البروفايلات المجمعة (الدرفة طول+عرض في بند واحد + رسمة المقطع الحقيقية لكل جزء)
    _drawTextInRect(
      canvas,
      Rect.fromLTWH(40, curY, canvasW - 80, 30),
      'أولاً: كشف القطاعات المجمعة (شاملاً تجميع طول وعرض الدرفة في بند واحد + قطاع إتش والبار) — عود ${storage.pricingSettings.defaultStockBarLengthCm.toStringAsFixed(0)} سم:',
      fontSize: 17.5,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF7F1D1D),
      textAlign: TextAlign.right,
    );
    curY += 34;

    final List<double> pCols = [90, 270, 410, 120, 270];
    final List<String> pHeaders = [
      'رسمة القطاع',
      'اسم البروفايل المجمع / القطاع',
      'مقاسات القص المجمعة (طول + عرض × عدد)',
      'عدد الأعواد',
      'تقسيم الأعواد والفضلة',
    ];

    double rx = canvasW - 40;
    for (int c = 0; c < pCols.length; c++) {
      final Rect hr = Rect.fromLTWH(rx - pCols[c], curY, pCols[c], 36);
      canvas.drawRect(hr, Paint()..color = const Color(0xFF31869B));
      canvas.drawRect(hr, borderPaint);
      _drawTextInRect(
        canvas,
        hr,
        pHeaders[c],
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      rx -= pCols[c];
    }
    curY += 36;

    final int profCount = aggregatedProfiles.length;
    final double dynamicProfRowH = profCount > 0
        ? ((maxProfilesEndY - curY) / profCount).clamp(46.0, 66.0)
        : 60.0;

    for (final prof in aggregatedProfiles) {
      if (curY + dynamicProfRowH > maxProfilesEndY) break;

      double cx = canvasW - 40;
      final String lengthsText = prof.dimensionBreakdownLabels.isNotEmpty
          ? prof.dimensionBreakdownLabels.join('  +  ')
          : prof.lengthCounts.entries
              .map((e) => '${e.key.toStringAsFixed(1)} سم × ${e.value}')
              .join('  ،  ');
      final barsSummary = prof.barPlans
          .take(2)
          .map((b) =>
              'عود#${b.barNumber}: [${b.cutsCm.map((x) => x.toStringAsFixed(0)).join("+")}] فضلة ${b.wasteLengthCm.toStringAsFixed(0)}سم')
          .join('\n');

      for (int c = 0; c < pCols.length; c++) {
        final Rect cr =
            Rect.fromLTWH(cx - pCols[c], curY, pCols[c], dynamicProfRowH);
        canvas.drawRect(cr, Paint()..color = Colors.white);
        canvas.drawRect(cr, borderPaint);

        if (c == 0) {
          final uiImg = prof.svgAssetPath != null
              ? profileImages[prof.svgAssetPath!]
              : null;
          if (uiImg != null) {
            paintImage(
              canvas: canvas,
              rect: cr.deflate(4),
              image: uiImg,
              fit: BoxFit.contain,
            );
          }
        } else if (c == 1) {
          _drawTextInRect(
            canvas,
            cr,
            '${prof.partName}\n(${prof.sectorName})',
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          );
        } else if (c == 2) {
          _drawTextInRect(
            canvas,
            cr,
            lengthsText,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          );
        } else if (c == 3) {
          canvas.drawRect(
              cr.deflate(2), Paint()..color = const Color(0xFFFEF3C7));
          _drawTextInRect(
            canvas,
            cr,
            '${prof.totalBarsNeeded} عود',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFB45309),
          );
        } else if (c == 4) {
          _drawTextInRect(
            canvas,
            cr,
            barsSummary,
            fontSize: 11,
            color: const Color(0xFF334155),
          );
        }

        cx -= pCols[c];
      }
      curY += dynamicProfRowH;
    }

    // ثانياً: جدول مقاسات الزجاج الصافية (شاملاً زجاج الدرف الأمامية وزجاج جميع الثوابت)
    curY += 16;
    _drawTextInRect(
      canvas,
      Rect.fromLTWH(40, curY, canvasW - 80, 30),
      'ثانياً: كشف مقاسات الزجاج الصافية والنوع والعدد (للضلف الأمامية وجميع الثوابت حسب معادلة كل قطاع):',
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF15803D),
      textAlign: TextAlign.right,
    );
    curY += 32;

    final List<double> gCols = [90, 290, 270, 190, 320];
    final List<String> gHeaders = [
      'الرمز',
      'البيان (الضلف / الثابت) والقطاع',
      'مقاس القطعة الصافي (عرض × ارتفاع)',
      'عدد القطع المطلوبة',
      'نوع الزجاج والملاحظات',
    ];

    rx = canvasW - 40;
    for (int c = 0; c < gCols.length; c++) {
      final Rect hr = Rect.fromLTWH(rx - gCols[c], curY, gCols[c], 34);
      canvas.drawRect(hr, Paint()..color = const Color(0xFF15803D));
      canvas.drawRect(hr, borderPaint);
      _drawTextInRect(
        canvas,
        hr,
        gHeaders[c],
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      rx -= gCols[c];
    }
    curY += 34;

    final double availGlassH = canvasH - curY - 28.0;
    final double glassRowH = allGlassPieces.isNotEmpty
        ? (availGlassH / allGlassPieces.length).clamp(28.0, 36.0)
        : 34.0;

    for (final gp in allGlassPieces) {
      if (curY + glassRowH > canvasH - 22) break;

      final bool isFixedPiece = gp.partLabel.contains('ثابت');
      final String countLabel = gp.isDoubleGlass
          ? '${gp.piecesCount} قطعة (دبل مزدوج)'
          : '${gp.piecesCount} قطعة (سنجل)';
      final String notesStr = gp.notes.isNotEmpty
          ? '${gp.glassDescription} • ${gp.notes}'
          : gp.glassDescription;

      final List<String> gVals = [
        gp.windowLabel,
        '${gp.partLabel} (${gp.sectorName})',
        '${gp.widthCm.toStringAsFixed(1)} × ${gp.heightCm.toStringAsFixed(1)} سم',
        countLabel,
        notesStr,
      ];

      double cx = canvasW - 40;
      for (int c = 0; c < gCols.length; c++) {
        final Rect cr = Rect.fromLTWH(cx - gCols[c], curY, gCols[c], glassRowH);
        canvas.drawRect(
          cr,
          Paint()
            ..color = isFixedPiece ? const Color(0xFFFFFBEB) : Colors.white,
        );
        canvas.drawRect(cr, borderPaint);
        _drawTextInRect(
          canvas,
          cr,
          gVals[c],
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: isFixedPiece && c == 1
              ? const Color(0xFFB45309)
              : Colors.black87,
        );
        cx -= gCols[c];
      }
      curY += glassRowH;
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(canvasW.toInt(), canvasH.toInt());
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// الصفحة الثانية من الطلبية: جدول الإكسسوارات الكامل (رينو، عضم، ميجا، تراك، مانع ارتجاج، عجل، مقابض...) + جدول الدورانات للإبلاغ فقط
  static Future<Uint8List> _renderOrderPage2AccessoriesAndArchesPng({
    required ClientRecord client,
    required WorkshopStorage storage,
    required List<CalculatedAccessoryOrderItem> calculatedAccessories,
    required List<ArchReportItem> archReports,
  }) async {
    const double canvasW = 1240.0;
    const double canvasH = 1754.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasW, canvasH));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()..color = Colors.white,
    );

    const Color tealHeader = Color(0xFF1E293B);

    const Rect headerBox = Rect.fromLTWH(40, 30, canvasW - 80, 90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headerBox, const Radius.circular(10)),
      Paint()..color = tealHeader,
    );

    if (_hafezLogoUiImage != null) {
      paintImage(
        canvas: canvas,
        rect: const Rect.fromLTWH(60, 40, 70, 70),
        image: _hafezLogoUiImage!,
        fit: BoxFit.contain,
      );
    }

    _drawTextInRect(
      canvas,
      const Rect.fromLTWH(150, 38, canvasW - 210, 40),
      'كشف حساب الطلبية (صفحة 2: الإكسسوارات الكاملة ومقاسات الدورانات للدرفلة) — شركة الحافظ',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: const Color(0xFFFDE68A),
      textAlign: TextAlign.right,
    );
    _drawTextInRect(
      canvas,
      const Rect.fromLTWH(150, 76, canvasW - 210, 34),
      'العميل: ${client.clientName}   |   العنوان: ${client.clientAddress}',
      fontSize: 16.5,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      textAlign: TextAlign.right,
    );

    double curY = 136.0;
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // ثالثاً: جدول الإكسسوارات المطلوبة للطلبية
    _drawTextInRect(
      canvas,
      Rect.fromLTWH(40, curY, canvasW - 80, 32),
      'ثالثاً: كشف الإكسسوارات ومستلزمات التجميع (رينو 90° • عضم • ميجا • تراك • مانع ارتجاج • عجل • مقابض • كاوتش • فرش):',
      fontSize: 17.5,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF1E3A8A),
      textAlign: TextAlign.right,
    );
    curY += 36;

    final List<double> aCols = [370, 210, 160, 420];
    final List<String> aHeaders = [
      'اسم الإكسسوار / الخامة',
      'التصنيف',
      'الكمية المطلوبة والوحدة',
      'الاستخدام والملاحظات الفنية',
    ];

    double rx = canvasW - 40;
    for (int c = 0; c < aCols.length; c++) {
      final Rect hr = Rect.fromLTWH(rx - aCols[c], curY, aCols[c], 38);
      canvas.drawRect(hr, Paint()..color = const Color(0xFF1E3A8A));
      canvas.drawRect(hr, borderPaint);
      _drawTextInRect(
        canvas,
        hr,
        aHeaders[c],
        fontSize: 14.5,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
      rx -= aCols[c];
    }
    curY += 38;

    for (final acc in calculatedAccessories) {
      const double rowH = 44.0;
      if (curY + rowH > canvasH - 360) break;

      final String qtyStr = acc.totalQuantity == acc.totalQuantity.roundToDouble()
          ? '${acc.totalQuantity.toInt()} ${acc.unit}'
          : '${acc.totalQuantity.toStringAsFixed(1)} ${acc.unit}';

      final List<String> aVals = [
        acc.name,
        acc.category,
        qtyStr,
        acc.notes,
      ];

      double cx = canvasW - 40;
      for (int c = 0; c < aCols.length; c++) {
        final Rect cr = Rect.fromLTWH(cx - aCols[c], curY, aCols[c], rowH);
        canvas.drawRect(
          cr,
          Paint()
            ..color = c == 2 ? const Color(0xFFFEF3C7) : Colors.white,
        );
        canvas.drawRect(cr, borderPaint);
        _drawTextInRect(
          canvas,
          cr,
          aVals[c],
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: c == 2 ? const Color(0xFFB45309) : Colors.black87,
        );
        cx -= aCols[c];
      }
      curY += rowH;
    }

    // رابعاً: بيان مقاسات الدورانات المطلوبة للدرفلة (للإبلاغ فقط دون تضليع في الأعواد)
    if (archReports.isNotEmpty) {
      curY += 24;
      _drawTextInRect(
        canvas,
        Rect.fromLTWH(40, curY, canvasW - 80, 32),
        'رابعاً: بيان مقاسات الدورانات (الأقواس) المطلوبة للدرفلة — للإبلاغ فقط دون تضليع في أعواد القص:',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF991B1B),
        textAlign: TextAlign.right,
      );
      curY += 36;

      final List<double> rCols = [90, 270, 200, 200, 200, 200];
      final List<String> rHeaders = [
        'الرمز',
        'القطاع واللون والعدد',
        'عرض الدوران / الوتر',
        'ارتفاع أقصى نقطة بالمنتصف',
        'نصف القطر الهندسي (R)',
        'طول القوس للدرفلة (+20سم)',
      ];

      rx = canvasW - 40;
      for (int c = 0; c < rCols.length; c++) {
        final Rect hr = Rect.fromLTWH(rx - rCols[c], curY, rCols[c], 38);
        canvas.drawRect(hr, Paint()..color = const Color(0xFF991B1B));
        canvas.drawRect(hr, borderPaint);
        _drawTextInRect(
          canvas,
          hr,
          rHeaders[c],
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );
        rx -= rCols[c];
      }
      curY += 38;

      for (final ar in archReports) {
        const double rowH = 44.0;
        if (curY + rowH > canvasH - 30) break;

        final List<String> rVals = [
          ar.windowLabel,
          '${ar.sectorName} (${ar.sectorColor}) × ${ar.quantity}',
          '${ar.chordWidthCm.toStringAsFixed(1)} سم',
          '${ar.archRiseHeightCm.toStringAsFixed(1)} سم',
          'R = ${ar.radiusCm.toStringAsFixed(1)} سم',
          'صافي ${ar.netArcLengthCm.toStringAsFixed(1)} سم (عود درفلة ${ar.rollingBarLengthCm.toStringAsFixed(0)} سم)',
        ];

        double cx = canvasW - 40;
        for (int c = 0; c < rCols.length; c++) {
          final Rect cr = Rect.fromLTWH(cx - rCols[c], curY, rCols[c], rowH);
          canvas.drawRect(cr, Paint()..color = const Color(0xFFFFFBEB));
          canvas.drawRect(cr, borderPaint);
          _drawTextInRect(
            canvas,
            cr,
            rVals[c],
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF7F1D1D),
          );
          cx -= rCols[c];
        }
        curY += rowH;
      }
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(canvasW.toInt(), canvasH.toInt());
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// شاشة الاستعراض والمعاينة الكاملة (Full Interactive Preview) لعرض السعر أو الطلبية قبل اتخاذ قرار تصدير الـ PDF
  static Future<void> openInteractiveReportPreviewScreen({
    required BuildContext context,
    required String title,
    required String defaultFileName,
    required Future<List<Uint8List>> Function() renderPagesPng,
    required Future<Uint8List> Function() buildPdfBytes,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _InteractiveReportPreviewPage(
          title: title,
          defaultFileName: defaultFileName,
          renderPagesPng: renderPagesPng,
          buildPdfBytes: buildPdfBytes,
        ),
      ),
    );
  }

  /// نافذة خيارات الاستعراض والحفظ والمشاركة للـ PDF
  static Future<void> showPdfExportOptionsSheet({
    required BuildContext context,
    required String title,
    required String defaultFileName,
    required Future<Uint8List> Function() buildBytes,
    Future<List<Uint8List>> Function()? renderPreviewPages,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        bool isBusy = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf,
                          color: Color(0xFF991B1B), size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15.5),
                        ),
                      ),
                      if (isBusy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                    ],
                  ),
                  const Divider(height: 18),

                  // الخيار 0 (جديد): استعراض ومراجعة التقرير كاملاً بحرية قبل تصدير الـ PDF
                  if (renderPreviewPages != null) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: isBusy
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              openInteractiveReportPreviewScreen(
                                context: context,
                                title: title,
                                defaultFileName: defaultFileName,
                                renderPagesPng: renderPreviewPages,
                                buildPdfBytes: buildBytes,
                              );
                            },
                      icon: const Icon(Icons.visibility),
                      label: const Text(
                        'استعراض ومراجعة التفاصيل كاملة بحرية قبل تصدير الـ PDF',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // الخيار 1: اختيار مكان الحفظ في مدير الملفات
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: isBusy
                        ? null
                        : () async {
                            setSheetState(() => isBusy = true);
                            final bytes = await buildBytes();
                            final savedUri =
                                await NativeFileService.savePdfWithFilePicker(
                              fileName: defaultFileName,
                              bytes: bytes,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted && savedUri != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF15803D),
                                  content: Text(
                                      '✅ تم حفظ ملف الـ PDF بنجاح في المكان المختار ($defaultFileName)'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.folder_open),
                    label: const Text(
                      'اختر مكان الحفظ في مدير الملفات (حفظ باسم...)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // الخيار 2: حفظ مباشر في مجلد التنزيلات (Downloads) ومعاينة/طباعة
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isBusy
                        ? null
                        : () async {
                            setSheetState(() => isBusy = true);
                            final bytes = await buildBytes();
                            final path = await NativeFileService
                                .savePdfToDownloadsDirect(
                              fileName: defaultFileName,
                              bytes: bytes,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('✅ تم الحفظ في التنزيلات: $path'),
                                ),
                              );
                            }
                            await Printing.layoutPdf(
                              name: defaultFileName,
                              onLayout: (_) async => bytes,
                            );
                          },
                    icon: const Icon(Icons.print),
                    label: const Text(
                      'حفظ تلقائي في التنزيلات (Download) + طباعة',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // الخيار 3: مشاركة عبر واتساب أو تليجرام
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isBusy
                        ? null
                        : () async {
                            setSheetState(() => isBusy = true);
                            final bytes = await buildBytes();
                            final tmpFile =
                                await NativeFileService.saveTempPdfForShare(
                              fileName: defaultFileName,
                              bytes: bytes,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await Share.shareXFiles(
                              [XFile(tmpFile.path)],
                              text: title,
                            );
                          },
                    icon: const Icon(Icons.share),
                    label: const Text(
                      'مشاركة الملف عبر واتساب / تليجرام / تطبيقات أخرى',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // دوال التوافق المباشرة
  static Future<File> savePdfToDevice({
    required Uint8List bytes,
    required String filename,
  }) async {
    await NativeFileService.savePdfToDownloadsDirect(
      fileName: filename,
      bytes: bytes,
    );
    return NativeFileService.saveTempPdfForShare(
      fileName: filename,
      bytes: bytes,
    );
  }

  static Future<File> savePdfToDeviceStorage({
    required Uint8List bytes,
    required String fileName,
  }) =>
      savePdfToDevice(bytes: bytes, filename: fileName);

  static Future<void> printOrSharePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static Future<void> previewPdfBytes(Uint8List bytes, String fileName) async {
    await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
  }

  static Future<Uint8List> buildOrderAndCuttingPdfBytes({
    required ClientRecord client,
    required WorkshopStorage storage,
  }) =>
      buildCuttingListPdfBytes(client: client, storage: storage);

  static Future<void> generateAndShareBothPdfs({
    required ClientRecord client,
    required WorkshopStorage storage,
  }) async {
    final quoteBytes =
        await buildQuotationPdfBytes(client: client, storage: storage);
    final orderBytes =
        await buildCuttingListPdfBytes(client: client, storage: storage);
    final f1 = await savePdfToDevice(
        bytes: quoteBytes,
        filename: 'عرض_سعر_شركة_الحافظ_${client.clientName}.pdf');
    final f2 = await savePdfToDevice(
        bytes: orderBytes,
        filename: 'كشف_طلبية_شركة_الحافظ_${client.clientName}.pdf');
    await Share.shareXFiles(
      [XFile(f1.path), XFile(f2.path)],
      text: 'عرض سعر وطلبية العميل: ${client.clientName}',
    );
  }
}

/// شاشة الاستعراض والمعاينة الحرة الكاملة (مع التكبير والتنقل بين الصفحات) قبل تصدير الـ PDF
class _InteractiveReportPreviewPage extends StatefulWidget {
  final String title;
  final String defaultFileName;
  final Future<List<Uint8List>> Function() renderPagesPng;
  final Future<Uint8List> Function() buildPdfBytes;

  const _InteractiveReportPreviewPage({
    required this.title,
    required this.defaultFileName,
    required this.renderPagesPng,
    required this.buildPdfBytes,
  });

  @override
  State<_InteractiveReportPreviewPage> createState() =>
      _InteractiveReportPreviewPageState();
}

class _InteractiveReportPreviewPageState
    extends State<_InteractiveReportPreviewPage> {
  List<Uint8List>? _pages;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    final list = await widget.renderPagesPng();
    if (mounted) {
      setState(() => _pages = list);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B110A),
        foregroundColor: Colors.white,
        title: Text(
          'استعراض ومراجعة: ${widget.title}',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
      ),
      body: _pages == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFF59E0B)),
                  SizedBox(height: 12),
                  Text(
                    'جارٍ تجهيز استعراض التقرير والرسومات الهندسية...',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: const Color(0xFF1E293B),
                  child: Text(
                    'يمكنك التكبير (Pinch to Zoom) والتحريك لمراجعة كافة المقاسات والقطاعات والزجاج والإكسسوارات والدورانات قبل تصدير الـ PDF (${_pages!.length} صفحة)',
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pages!.length,
                    itemBuilder: (ctx, idx) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 4,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              color: const Color(0xFF334155),
                              child: Text(
                                'صفحة ${idx + 1} من ${_pages!.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 4.0,
                              child: Image.memory(
                                _pages![idx],
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: const Color(0xFF1B110A),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    setState(() => _isSaving = true);
                                    final bytes = await widget.buildPdfBytes();
                                    final saved = await NativeFileService
                                        .savePdfWithFilePicker(
                                      fileName: widget.defaultFileName,
                                      bytes: bytes,
                                    );
                                    if (!mounted) return;
                                    setState(() => _isSaving = false);
                                    if (saved != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              const Color(0xFF15803D),
                                          content: Text(
                                              '✅ تم تصدير وحفظ ${widget.defaultFileName} بنجاح'),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.save_alt),
                            label: const Text(
                              'اعتماد وتصدير كملف PDF (حفظ بمدير الملفات)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  final bytes = await widget.buildPdfBytes();
                                  final tmp = await NativeFileService
                                      .saveTempPdfForShare(
                                    fileName: widget.defaultFileName,
                                    bytes: bytes,
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  await Share.shareXFiles(
                                    [XFile(tmp.path)],
                                    text: widget.title,
                                  );
                                },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text(
                            'مشاركة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
