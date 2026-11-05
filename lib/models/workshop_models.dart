import 'dart:math' as math;

/// جزء داخل القطاع (حلق، ضلفة مجمعة طول+عرض، سكينة، منخل/سلك، سؤاس، باكتة، بار، كعب باب، إتش...)
class SectorPart {
  String id;
  String name;
  String role; // حلق | ضلفة | سكينة | منخل | سؤاس | باكتة | بار | باندا | إتش | كعب
  String dimensionBasis; // width | height | net_width | net_height | net_width_per_sash | fixed
  double offsetCm; // التخصيم الافتراضي (لضلفتين في الجرار أو المفصلي)
  double? offset1SashCm; // تخصيم الضلفة الواحدة (إن اختلف)
  double? offset3SashCm; // تخصيم الـ 3 ضلف (إن اختلف)
  double? offset4SashCm; // تخصيم الـ 4 ضلف (إن اختلف)
  int quantityPerWindow;
  bool multiplyBySashes;
  String? svgAssetPath; // مسار رسمة بروفايل الألومنيوم (SVG) الخاصة بهذا الجزء تحديداً
  String condition; // always | with_bar | without_bar | fly_screen | window_only | door_only | fixed_only | single_glass | double_glass | track_3 | panda_only

  SectorPart({
    required this.id,
    required this.name,
    required this.role,
    this.dimensionBasis = 'width',
    this.offsetCm = 0.0,
    this.offset1SashCm,
    this.offset3SashCm,
    this.offset4SashCm,
    this.quantityPerWindow = 2,
    this.multiplyBySashes = false,
    this.svgAssetPath,
    this.condition = 'always',
  });

  String get formulaType => dimensionBasis;
  set formulaType(String val) => dimensionBasis = val;

  int get countMultiplier => quantityPerWindow;
  set countMultiplier(int val) => quantityPerWindow = val;

  double effectiveOffsetForSashes(int sashCount) {
    if (sashCount <= 1 && offset1SashCm != null) return offset1SashCm!;
    if (sashCount == 3 && offset3SashCm != null) return offset3SashCm!;
    if (sashCount >= 4 && offset4SashCm != null) return offset4SashCm!;
    return offsetCm;
  }

  /// حساب طول القطعة الواحدة بالسنتيمتر بناءً على أبعاد الشباك الكلية والصافية وعدد الضلف
  double calculatePieceLength(
    double totalWidthCm,
    double totalHeightCm,
    int sashCount, {
    double? netWidthCm,
    double? netHeightCm,
  }) {
    final int safeSashes = sashCount > 0 ? sashCount : 1;
    final double wNet = netWidthCm ?? totalWidthCm;
    final double hNet = netHeightCm ?? totalHeightCm;
    final double activeOffset = effectiveOffsetForSashes(safeSashes);

    double base = 0.0;
    switch (dimensionBasis) {
      case 'width':
        base = totalWidthCm + activeOffset;
        break;
      case 'height':
        base = totalHeightCm + activeOffset;
        break;
      case 'net_width':
        base = wNet + activeOffset;
        break;
      case 'net_height':
        base = hNet + activeOffset;
        break;
      case 'width_per_sash':
      case 'width_div_sashes':
        base = (totalWidthCm / safeSashes) + activeOffset;
        break;
      case 'net_width_per_sash':
        base = (wNet / safeSashes) + activeOffset;
        break;
      case 'fixed':
        base = activeOffset;
        break;
      default:
        base = wNet + activeOffset;
    }
    return base > 0 ? double.parse(base.toStringAsFixed(2)) : 0.0;
  }

  /// إجمالي عدد القطع لهذا الجزء في الشباك
  int calculateTotalCount(int windowQuantity, int sashCount) {
    final int safeSashes = sashCount > 0 ? sashCount : 1;
    final int safeQty = windowQuantity > 0 ? windowQuantity : 1;
    final int perWin =
        multiplyBySashes ? (quantityPerWindow * safeSashes) : quantityPerWindow;
    return perWin * safeQty;
  }

  String get basisArabicLabel {
    switch (dimensionBasis) {
      case 'width':
        return 'العرض الكلي';
      case 'height':
        return 'الارتفاع الكلي';
      case 'net_width':
        return 'صافي عرض المتحرك';
      case 'net_height':
        return 'صافي ارتفاع المتحرك';
      case 'width_per_sash':
      case 'width_div_sashes':
      case 'net_width_per_sash':
        return 'صافي العرض ÷ عدد الضلف';
      case 'fixed':
        return 'مقاس ثابت';
      default:
        return 'العرض';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'dimensionBasis': dimensionBasis,
        'offsetCm': offsetCm,
        'offset1SashCm': offset1SashCm,
        'offset3SashCm': offset3SashCm,
        'offset4SashCm': offset4SashCm,
        'quantityPerWindow': quantityPerWindow,
        'multiplyBySashes': multiplyBySashes,
        'svgAssetPath': svgAssetPath,
        'condition': condition,
      };

  factory SectorPart.fromJson(Map<String, dynamic> json) => SectorPart(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        role: json['role'] ?? 'حلق',
        dimensionBasis:
            json['dimensionBasis'] ?? json['formulaType'] ?? 'width',
        offsetCm: (json['offsetCm'] as num?)?.toDouble() ?? 0.0,
        offset1SashCm: (json['offset1SashCm'] as num?)?.toDouble(),
        offset3SashCm: (json['offset3SashCm'] as num?)?.toDouble(),
        offset4SashCm: (json['offset4SashCm'] as num?)?.toDouble(),
        quantityPerWindow:
            json['quantityPerWindow'] ?? json['countMultiplier'] ?? 2,
        multiplyBySashes: json['multiplyBySashes'] ?? false,
        svgAssetPath: json['svgAssetPath'],
        condition: json['condition'] ?? 'always',
      );
}

/// قطعة زجاج مفصلة في كشف حساب الطلبية والـ PDF (سواء زجاج ضلفة متحركة أو زجاج ثابت)
class GlassCutPiece {
  final String windowLabel; // W1, W2...
  final String partLabel; // مثل: زجاج الضلف الأمامية (2 ضلفة) | زجاج ثابت علوي (مقسوم 3)
  final String sectorName;
  final double widthCm;
  final double heightCm;
  final int piecesCount; // عدد القطع (لو ضلفة = 1، ضلفتين = 2، 4 ضلف = 4، وللباندا يحسب على الدرف الأمامية فقط)
  final bool isDoubleGlass;
  final String glassDescription;
  final String notes;

  const GlassCutPiece({
    required this.windowLabel,
    required this.partLabel,
    required this.sectorName,
    required this.widthCm,
    required this.heightCm,
    required this.piecesCount,
    required this.isDoubleGlass,
    required this.glassDescription,
    this.notes = '',
  });
}

/// بند إكسسوار محسوب في الطلبية (مقابض، عجل، رينو 90 درجة، عضم، ميجا، تراك، مانع ارتجاج، كاوتش، فرش...)
class CalculatedAccessoryOrderItem {
  final String id;
  final String name;
  final String category; // تجميع وزوايا رينو | حركة وعجل ومفصلات | مقابض وميجا وتراك | كاوتش وفرش وسلك
  final String unit; // قطعة | طقم | متر طولي | متر مربع
  final double totalQuantity;
  final double unitPrice;
  final String notes;

  const CalculatedAccessoryOrderItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.totalQuantity,
    required this.unitPrice,
    this.notes = '',
  });

  double get totalCost => totalQuantity * unitPrice;
}

/// بيان مقاس الدوران (القوس) المطلوب إبلاغ ورشة الدرفلة به دون تضليعه في أعواد القص
class ArchReportItem {
  final String windowLabel; // W1, W2
  final String sectorName;
  final String sectorColor;
  final int quantity;
  final double chordWidthCm; // عرض الدوران (الوتر)
  final double archRiseHeightCm; // ارتفاع الدوران من أقصى نقطة في المنتصف (السهم)
  final double radiusCm; // نصف القطر الهندسي R
  final double netArcLengthCm; // طول القوس الصافي
  final double rollingBarLengthCm; // طول العود المطلوب للدرفلة (شاملاً 20 سم ركوب الدرفلة)
  final double archPricePerWindow;

  const ArchReportItem({
    required this.windowLabel,
    required this.sectorName,
    required this.sectorColor,
    required this.quantity,
    required this.chordWidthCm,
    required this.archRiseHeightCm,
    required this.radiusCm,
    required this.netArcLengthCm,
    required this.rollingBarLengthCm,
    required this.archPricePerWindow,
  });

  double get totalArchCost => archPricePerWindow * quantity;
}

/// تعريف القطاع الكامل (الألومنيوم / UPVC / المطابخ) مع صور مقاطعه ومعادلاته وكتالوجه
class SectorProfile {
  String id;
  String name;
  String shortPdfName; // الاسم المختصر الذي يطبع في جدول عرض السعر
  String category; // منزلق | مفصلي
  String companyGroup; // قطاعات السلام (PS) | قطاعات الشريف | فالف القباري | الدولية 21 ماكسيم | ألوميل | فولكانو | UPVC
  String systemType; // شباك جرار | شباك مفصلي | باب مفصلي | مطبخ
  int defaultSashCount;
  String? imagePath; // صورة مخصصة من الكاميرا أو المعرض
  String? companyLogoAsset; // أيقونة الشركة من assets/images/windows/systems/
  String? profileSvgFolder; // مجلد رسومات الـ SVG الخاصة بالقطاع
  String? fixedTransomSvg; // مسار رسمة السؤاس / القاطع للثوابت
  String? fixedBeadSingleSvg; // مسار رسمة الباكتة السنجل للثوابت
  String? fixedBeadDoubleSvg; // مسار رسمة الباكتة الدبل للثوابت
  String? hConnectorSvg; // مسار رسمة قطاع "إتش" (H-profile) الفاصل بين الجرار والثابت العلوي
  String? architraveBarSvg; // مسار رسمة البار المنفصل الذي يلتف حوالين داير
  String? doorKickplateSvg; // مسار رسمة كعب الباب العريض للأبواب
  String catalogUrl; // رابط الكتالوج الخارجي (Google Drive / موقع الشركة)
  double pricePerSquareMeter; // السعر الافتراضي للمتر المسطح محسوباً بالزجاج العاكس البني كـ Default
  double barPrice; // سعر العود القياسي (6 متر)
  double glassWidthDeductCm; // خصم عرض الزجاج من عرض الضلفة الصافي
  double glassHeightDeductCm; // خصم ارتفاع الزجاج من ارتفاع الضلفة الصافي
  double fixedGlassDeductCm; // خصم الزجاج للجزء الثابت من الحلق (عرضاً وارتفاعاً)
  double transomDeductCm; // خصم السؤاس عند تقسيم الثابت أو عمل قاطع
  bool isCustom;
  List<SectorPart> parts;

  SectorProfile({
    required this.id,
    required this.name,
    String? shortPdfName,
    required this.category,
    String? companyGroup,
    String? systemType,
    this.defaultSashCount = 2,
    this.imagePath,
    this.companyLogoAsset,
    this.profileSvgFolder,
    this.fixedTransomSvg,
    this.fixedBeadSingleSvg,
    this.fixedBeadDoubleSvg,
    this.hConnectorSvg,
    this.architraveBarSvg,
    this.doorKickplateSvg,
    this.catalogUrl = '',
    required this.pricePerSquareMeter,
    this.barPrice = 1450.0,
    this.glassWidthDeductCm = 10.6,
    this.glassHeightDeductCm = 10.6,
    this.fixedGlassDeductCm = 6.4,
    this.transomDeductCm = 5.6,
    this.isCustom = false,
    required this.parts,
  })  : shortPdfName = shortPdfName ?? name,
        companyGroup = companyGroup ?? category,
        systemType = systemType ??
            (category.contains('منزلق') || category.contains('جرار')
                ? 'شباك جرار'
                : 'شباك مفصلي');

  /// هل القطاع منزلق (جرار) أم مفصلي؟
  bool get isSliding =>
      category == 'منزلق' ||
      category.contains('جرار') ||
      systemType.contains('جرار') ||
      systemType.contains('منزلق');

  bool get isHinged => !isSliding;

  /// أول رسمة SVG متاحة في القطاع لعرضها كأيقونة مصغرة للقطاع
  String? get primaryProfileSvg {
    for (final p in parts) {
      if (p.svgAssetPath != null && p.svgAssetPath!.isNotEmpty) {
        return p.svgAssetPath;
      }
    }
    if (profileSvgFolder != null && profileSvgFolder!.isNotEmpty) {
      return '$profileSvgFolder/001.svg';
    }
    return 'assets/images/svg/profiles/001.svg';
  }

  /// البحث عن جزء الدرفة الأساسي لاستخراج تخصيم عرض وارتفاع الدرفة الفعلي في هذا القطاع
  SectorPart? _findPrimarySashWidthPart({bool isDoor = false}) {
    for (final p in parts) {
      final bool roleMatch = p.role == 'ضلفة' || p.role == 'درفة';
      final bool basisMatch = p.dimensionBasis.contains('width');
      final bool doorMatch = isDoor
          ? (p.condition == 'door_only' || p.condition == 'always')
          : (p.condition == 'window_only' || p.condition == 'always');
      if (roleMatch && basisMatch && doorMatch) return p;
    }
    for (final p in parts) {
      if ((p.role == 'ضلفة' || p.role == 'درفة') &&
          p.dimensionBasis.contains('width')) {
        return p;
      }
    }
    return null;
  }

  SectorPart? _findPrimarySashHeightPart({bool isDoor = false}) {
    for (final p in parts) {
      final bool roleMatch = p.role == 'ضلفة' || p.role == 'درفة';
      final bool basisMatch = p.dimensionBasis.contains('height');
      final bool doorMatch = isDoor
          ? (p.condition == 'door_only' || p.condition == 'always')
          : (p.condition == 'window_only' || p.condition == 'always');
      if (roleMatch && basisMatch && doorMatch) return p;
    }
    for (final p in parts) {
      if ((p.role == 'ضلفة' || p.role == 'درفة') &&
          p.dimensionBasis.contains('height')) {
        return p;
      }
    }
    return null;
  }

  /// حساب عرض لوح الزجاج الواحد للضلفة الصافي بالسنتيمتر حسب معادلة القطاع في المشروع المماثل:
  /// عرض الزجاج = عرض الضلفة الصافي - خصم عرض الزجاج للقطاع (glassWidthDeductCm)
  double calculateGlassWidthCm(
    double netWidthCm,
    int sashCount, {
    bool isDoor = false,
    bool isFixedWindow = false,
  }) {
    final int s = sashCount > 0 ? sashCount : 1;
    if (isFixedWindow) {
      return calculateFixedPaneGlassWidth(netWidthCm, s);
    }
    final sashWPart = _findPrimarySashWidthPart(isDoor: isDoor);
    final double sashW = sashWPart != null
        ? sashWPart.calculatePieceLength(netWidthCm, 100.0, s,
            netWidthCm: netWidthCm)
        : (netWidthCm / s);
    final double val = sashW - glassWidthDeductCm;
    return val > 0 ? double.parse(val.toStringAsFixed(1)) : 0.0;
  }

  /// حساب ارتفاع لوح الزجاج الواحد للضلفة الصافي بالسنتيمتر حسب معادلة القطاع في المشروع المماثل:
  /// ارتفاع الزجاج = ارتفاع الضلفة الصافي - خصم ارتفاع الزجاج للقطاع (glassHeightDeductCm)
  double calculateGlassHeightCm(
    double netHeightCm,
    int sashCount, {
    bool isDoor = false,
    bool isFixedWindow = false,
  }) {
    final int s = sashCount > 0 ? sashCount : 1;
    if (isFixedWindow) {
      return calculateFixedPaneGlassHeight(netHeightCm, 1);
    }
    final sashHPart = _findPrimarySashHeightPart(isDoor: isDoor);
    final double sashH = sashHPart != null
        ? sashHPart.calculatePieceLength(100.0, netHeightCm, s,
            netHeightCm: netHeightCm)
        : (netHeightCm - 6.0);
    final double val = sashH - glassHeightDeductCm;
    return val > 0 ? double.parse(val.toStringAsFixed(1)) : 0.0;
  }

  /// حساب صافي عرض زجاج الجزء الثابت (ولو الثابت مقسم لعدة أجزاء يخصم السؤاس ويقسم على عدد الأجزاء)
  double calculateFixedPaneGlassWidth(double fixedTotalWidthCm, int splits) {
    final int safeSplits = splits > 0 ? splits : 1;
    final double totalMullionsDeduction = (safeSplits - 1) * (transomDeductCm * 0.45);
    final double singleCellW =
        ((fixedTotalWidthCm - totalMullionsDeduction) / safeSplits) -
            fixedGlassDeductCm;
    return singleCellW > 0 ? double.parse(singleCellW.toStringAsFixed(1)) : 0.0;
  }

  /// حساب صافي ارتفاع زجاج الجزء الثابت (ولو الثابت الرأسي مقسم لعدة أجزاء يقسم على عدد الأجزاء)
  double calculateFixedPaneGlassHeight(double fixedTotalHeightCm, int splits) {
    final int safeSplits = splits > 0 ? splits : 1;
    final double totalMullionsDeduction = (safeSplits - 1) * (transomDeductCm * 0.45);
    final double singleCellH =
        ((fixedTotalHeightCm - totalMullionsDeduction) / safeSplits) -
            fixedGlassDeductCm;
    return singleCellH > 0 ? double.parse(singleCellH.toStringAsFixed(1)) : 0.0;
  }

  /// استخراج قائمة تفصيلية بجميع قطع الزجاج المطلوبة للشباك:
  /// - زجاج الدرف الأمامية (1 درفة = 1 قطعة، 2 درفة = 2 قطعة، 4 درف = 4 قطع؛ وفي نظام الباندا يحسب على الدرف الأمامية فقط)
  /// - زجاج الثابت العلوي، السفلي، اليمين، الشمال (بعدد أجزائها ومعادلات القطاع بالضبط)
  List<GlassCutPiece> buildWindowGlassCutList(ClientWindowItem item) {
    if (!item.hasGlass) return [];
    final List<GlassCutPiece> list = [];
    final bool isDoor = item.unitType.contains('باب');
    final bool isFixedWin = item.openType == 'ثابت';
    final int safeSashes = item.sashCount > 0 ? item.sashCount : 1;
    final int safeQty = item.quantity > 0 ? item.quantity : 1;
    final String glassDesc = item.glassSummaryText.replaceAll('\n', ' ');

    // 1. زجاج الدرف الأمامية (أو الشباك الثابت)
    // في حالة الباندا: الدرف الخلفية للسلك والدرف الأمامية للزجاج، فيُحسب الزجاج على الدرف الأمامية فقط
    double sashGw = calculateGlassWidthCm(
      item.netOperableWidthCm,
      safeSashes,
      isDoor: isDoor,
      isFixedWindow: isFixedWin,
    );
    double sashGh = calculateGlassHeightCm(
      item.netOperableHeightCm,
      safeSashes,
      isDoor: isDoor,
      isFixedWindow: isFixedWin,
    );

    // إذا كان الباب به جلسة/حشو سفلي فايبر وعارضة وسط، يخصم ارتفاع الحشو السفلي من ارتفاع زجاج الباب
    String doorNote = '';
    if (isDoor && item.hasDoorMiddleMullion && item.doorBottomPanelType != 'زجاج') {
      sashGh = math.max(20.0, sashGh - item.doorBottomKickHeightCm);
      doorNote =
          'الجزء العلوي زجاج والجزء السفلي (${item.doorBottomKickHeightCm.toStringAsFixed(0)} سم) ${item.doorBottomPanelType}';
    }

    final int sashGlassPiecesCount = safeSashes * safeQty;
    final String pandaGlassTag =
        (item.hasPanda && item.openType.contains('مفصلي'))
            ? ' [الدرف الأمامية للباندا فقط]'
            : '';

    list.add(
      GlassCutPiece(
        windowLabel: item.label,
        partLabel: isFixedWin
            ? 'زجاج ثابت أساسي ($safeSashes جزء)'
            : 'زجاج ${item.openType} ($safeSashes ضلفة)$pandaGlassTag',
        sectorName: shortPdfName,
        widthCm: sashGw,
        heightCm: sashGh,
        piecesCount: sashGlassPiecesCount,
        isDoubleGlass: item.isDoubleGlass,
        glassDescription: glassDesc,
        notes: doorNote,
      ),
    );

    // 2. زجاج الثابت العلوي (إن وجد)
    if (item.hasTopFixed && item.topFixedHeightCm > 0) {
      final int splits = math.max(1, item.topFixedSplits);
      final double topGw = calculateFixedPaneGlassWidth(item.widthCm, splits);
      final double topGh = calculateFixedPaneGlassHeight(item.topFixedHeightCm, 1);
      final bool fanHere = item.hasExhaustFan &&
          item.exhaustFanPosition.contains('العلوي');
      list.add(
        GlassCutPiece(
          windowLabel: item.label,
          partLabel: splits > 1
              ? 'زجاج ثابت علوي (مقسوم $splits أجزاء)'
              : 'زجاج ثابت علوي (قطعة واحدة)',
          sectorName: shortPdfName,
          widthCm: topGw,
          heightCm: topGh,
          piecesCount: splits * safeQty,
          isDoubleGlass: item.isDoubleGlass,
          glassDescription: glassDesc,
          notes: fanHere
              ? 'الجزء رقم ${math.min(splits, item.exhaustFanPartIndex + 1)} به فتحة شفاط (${item.exhaustFanDiameterCm.toStringAsFixed(0)} سم)'
              : '',
        ),
      );
    }

    // 3. زجاج الثابت السفلي (إن وجد)
    if (item.hasBottomFixed && item.bottomFixedHeightCm > 0) {
      final int splits = math.max(1, item.bottomFixedSplits);
      final double botGw = calculateFixedPaneGlassWidth(item.widthCm, splits);
      final double botGh = calculateFixedPaneGlassHeight(item.bottomFixedHeightCm, 1);
      final bool fanHere = item.hasExhaustFan &&
          item.exhaustFanPosition.contains('السفلي');
      list.add(
        GlassCutPiece(
          windowLabel: item.label,
          partLabel: splits > 1
              ? 'زجاج ثابت سفلي (مقسوم $splits أجزاء)'
              : 'زجاج ثابت سفلي (قطعة واحدة)',
          sectorName: shortPdfName,
          widthCm: botGw,
          heightCm: botGh,
          piecesCount: splits * safeQty,
          isDoubleGlass: item.isDoubleGlass,
          glassDescription: glassDesc,
          notes: fanHere
              ? 'الجزء رقم ${math.min(splits, item.exhaustFanPartIndex + 1)} به فتحة شفاط (${item.exhaustFanDiameterCm.toStringAsFixed(0)} سم)'
              : '',
        ),
      );
    }

    // 4. زجاج الثابت اليمين (إن وجد)
    if (item.hasRightFixed && item.rightFixedWidthCm > 0) {
      final int splits = math.max(1, item.rightFixedSplits);
      final double rightGw = calculateFixedPaneGlassWidth(item.rightFixedWidthCm, 1);
      final double rightGh =
          calculateFixedPaneGlassHeight(item.netOperableHeightCm, splits);
      final bool fanHere = item.hasExhaustFan &&
          item.exhaustFanPosition.contains('اليمين');
      list.add(
        GlassCutPiece(
          windowLabel: item.label,
          partLabel: splits > 1
              ? 'زجاج ثابت يمين (مقسوم $splits أجزاء)'
              : 'زجاج ثابت يمين (قطعة واحدة)',
          sectorName: shortPdfName,
          widthCm: rightGw,
          heightCm: rightGh,
          piecesCount: splits * safeQty,
          isDoubleGlass: item.isDoubleGlass,
          glassDescription: glassDesc,
          notes: fanHere
              ? 'الجزء رقم ${math.min(splits, item.exhaustFanPartIndex + 1)} به فتحة شفاط (${item.exhaustFanDiameterCm.toStringAsFixed(0)} سم)'
              : '',
        ),
      );
    }

    // 5. زجاج الثابت الشمال (إن وجد)
    if (item.hasLeftFixed && item.leftFixedWidthCm > 0) {
      final int splits = math.max(1, item.leftFixedSplits);
      final double leftGw = calculateFixedPaneGlassWidth(item.leftFixedWidthCm, 1);
      final double leftGh =
          calculateFixedPaneGlassHeight(item.netOperableHeightCm, splits);
      final bool fanHere = item.hasExhaustFan &&
          item.exhaustFanPosition.contains('الشمال');
      list.add(
        GlassCutPiece(
          windowLabel: item.label,
          partLabel: splits > 1
              ? 'زجاج ثابت شمال (مقسوم $splits أجزاء)'
              : 'زجاج ثابت شمال (قطعة واحدة)',
          sectorName: shortPdfName,
          widthCm: leftGw,
          heightCm: leftGh,
          piecesCount: splits * safeQty,
          isDoubleGlass: item.isDoubleGlass,
          glassDescription: glassDesc,
          notes: fanHere
              ? 'الجزء رقم ${math.min(splits, item.exhaustFanPartIndex + 1)} به فتحة شفاط (${item.exhaustFanDiameterCm.toStringAsFixed(0)} سم)'
              : '',
        ),
      );
    }

    return list;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortPdfName': shortPdfName,
        'category': category,
        'companyGroup': companyGroup,
        'systemType': systemType,
        'defaultSashCount': defaultSashCount,
        'imagePath': imagePath,
        'companyLogoAsset': companyLogoAsset,
        'profileSvgFolder': profileSvgFolder,
        'fixedTransomSvg': fixedTransomSvg,
        'fixedBeadSingleSvg': fixedBeadSingleSvg,
        'fixedBeadDoubleSvg': fixedBeadDoubleSvg,
        'hConnectorSvg': hConnectorSvg,
        'architraveBarSvg': architraveBarSvg,
        'doorKickplateSvg': doorKickplateSvg,
        'catalogUrl': catalogUrl,
        'pricePerSquareMeter': pricePerSquareMeter,
        'barPrice': barPrice,
        'glassWidthDeductCm': glassWidthDeductCm,
        'glassHeightDeductCm': glassHeightDeductCm,
        'fixedGlassDeductCm': fixedGlassDeductCm,
        'transomDeductCm': transomDeductCm,
        'isCustom': isCustom,
        'parts': parts.map((e) => e.toJson()).toList(),
      };

  factory SectorProfile.fromJson(Map<String, dynamic> json) => SectorProfile(
        id: json['id'] ?? '',
        name: (json['name'] ?? '')
            .toString()
            .replaceAll('قطاعات السعد', 'قطاعات السلام')
            .replaceAll('قطاع السعد', 'قطاع السلام')
            .replaceAll('مركز الماكينات - الشارقة', 'قطاعات الشريف'),
        shortPdfName: json['shortPdfName'] ?? json['name'] ?? '',
        category: json['category'] ?? 'منزلق',
        companyGroup: (json['companyGroup'] ?? json['category'] ?? 'عام')
            .toString()
            .replaceAll('قطاعات السعد (PS)', 'قطاعات السلام (PS)')
            .replaceAll('قطاعات السعد', 'قطاعات السلام (PS)')
            .replaceAll('قطاع السعد', 'قطاعات السلام (PS)')
            .replaceAll('مركز الماكينات - الشارقة', 'قطاعات الشريف')
            .replaceAll('المكنات الشرقا', 'قطاعات الشريف'),
        systemType: json['systemType'] ?? json['category'] ?? 'شباك جرار',
        defaultSashCount: json['defaultSashCount'] ?? 2,
        imagePath: json['imagePath'],
        companyLogoAsset: json['companyLogoAsset'],
        profileSvgFolder: json['profileSvgFolder'],
        fixedTransomSvg: json['fixedTransomSvg'],
        fixedBeadSingleSvg: json['fixedBeadSingleSvg'],
        fixedBeadDoubleSvg: json['fixedBeadDoubleSvg'],
        hConnectorSvg: json['hConnectorSvg'],
        architraveBarSvg: json['architraveBarSvg'],
        doorKickplateSvg: json['doorKickplateSvg'],
        catalogUrl: json['catalogUrl']?.toString() ?? '',
        pricePerSquareMeter:
            (json['pricePerSquareMeter'] as num?)?.toDouble() ?? 4500.0,
        barPrice: (json['barPrice'] as num?)?.toDouble() ?? 1450.0,
        glassWidthDeductCm:
            (json['glassWidthDeductCm'] as num?)?.toDouble() ?? 10.6,
        glassHeightDeductCm:
            (json['glassHeightDeductCm'] as num?)?.toDouble() ?? 10.6,
        fixedGlassDeductCm:
            (json['fixedGlassDeductCm'] as num?)?.toDouble() ?? 6.4,
        transomDeductCm:
            (json['transomDeductCm'] as num?)?.toDouble() ?? 5.6,
        isCustom: json['isCustom'] ?? false,
        parts: (json['parts'] as List<dynamic>?)
                ?.map((e) => SectorPart.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

/// نوع الزجاج في قائمة التسعير
class GlassTypeItem {
  String id;
  String name; // مثل: عاكس بني 6 مم (الافتراضي الأساسي) / عاكس أزرق 6 مم / شفاف 6 مم
  double pricePerSquareMeter;
  String thickness;
  String color;
  bool isDoublePreset;
  bool isDefaultBaseline; // هل هذا هو الزجاج العاكس البني الافتراضي الذي يُبنى عليه سعر المتر الأساسي؟

  GlassTypeItem({
    required this.id,
    required this.name,
    required this.pricePerSquareMeter,
    this.thickness = '6 مم',
    this.color = 'عاكس بني',
    this.isDoublePreset = false,
    this.isDefaultBaseline = false,
  });

  String get cleanSingleName => name
      .replaceAll('\n', ' ')
      .replaceAll('سنجل ', '')
      .replaceAll('دبل ', '')
      .replaceAll('(الافتراضي الأساسي)', '')
      .trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pricePerSquareMeter': pricePerSquareMeter,
        'thickness': thickness,
        'color': color,
        'isDoublePreset': isDoublePreset,
        'isDefaultBaseline': isDefaultBaseline,
      };

  factory GlassTypeItem.fromJson(Map<String, dynamic> json) => GlassTypeItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        pricePerSquareMeter:
            (json['pricePerSquareMeter'] as num?)?.toDouble() ?? 600.0,
        thickness: json['thickness'] ?? '6 مم',
        color: json['color'] ?? 'عاكس بني',
        isDoublePreset: json['isDoublePreset'] ?? false,
        isDefaultBaseline: json['isDefaultBaseline'] ??
            (json['name']?.toString().contains('عاكس بني') ?? false),
      );
}

/// بند إكسسوار أو إضافات في قائمة التسعير
class AccessoryPriceItem {
  String id;
  String name;
  String unit; // متر مربع | متر طولي | قطعة | طقم
  double price;

  AccessoryPriceItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
      };

  factory AccessoryPriceItem.fromJson(Map<String, dynamic> json) =>
      AccessoryPriceItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        unit: json['unit'] ?? 'قطعة',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
      );
}

/// إعدادات التسعير والورشة الشاملة
class PricingSettings {
  double baselineBrownReflectiveGlassPricePerM2; // سعر الزجاج العاكس البني الافتراضي (الأساس)
  double doubleSpacerPricePerMeter;
  double georgianBarPricePerMeter;
  double flyScreenPricePerM2;
  double shutterPricePerM2;
  double exhaustFanPrice;
  double defaultArchPrice;
  double defaultStockBarLengthCm;
  double defaultSawKerfMm;
  bool enforceMinimumOneSquareMeter;

  String companyName;
  String companySubtitle;
  String companyPhones;
  String companyAddress;
  String pdfNoteLine1;
  String pdfNoteLine2;
  String pdfNoteLine3;
  String pdfNoteLine4;
  String pdfNoteLine5;
  String pdfNoteLine6;
  String termsAndConditions;

  PricingSettings({
    this.baselineBrownReflectiveGlassPricePerM2 = 600.0,
    this.doubleSpacerPricePerMeter = 150.0,
    this.georgianBarPricePerMeter = 85.0,
    this.flyScreenPricePerM2 = 250.0,
    this.shutterPricePerM2 = 1800.0,
    this.exhaustFanPrice = 350.0,
    this.defaultArchPrice = 600.0,
    this.defaultStockBarLengthCm = 600.0,
    this.defaultSawKerfMm = 4.0,
    this.enforceMinimumOneSquareMeter = true,
    this.companyName = 'شركة الحافظ',
    this.companySubtitle =
        'للمطابخ الألومنيوم والخشب وجميع أعمال الأخشاب والواجهات الزجاجية',
    this.companyPhones = '01000000000 - 01200000000',
    this.companyAddress = 'جمهورية مصر العربية',
    this.pdfNoteLine1 = 'ملحوظة هامة : السعر لا يشمل النقل والمشال',
    this.pdfNoteLine2 =
        'نوع القطاع Emapen الحاصل على شهادة الايزو ISO 9001 + جميع الاكسسوارات تركية الصنع',
    this.pdfNoteLine3 = 'ضمان ٢٠ سنة على القطاع + ٥ أعوام على الاكسسوارات',
    this.pdfNoteLine4 = 'القطاعات كلها مدعمة بكاوتش مدمج بها',
    this.pdfNoteLine5 =
        'القطاعات كلها مدعمة بحديد مجلفن سماكة ١.٢٥ ملل من الداخل',
    this.pdfNoteLine6 = 'الاسعار غير شاملة الضريبة',
    this.termsAndConditions =
        'عند التعاقد دفعة ٦٠ % // عند التوريد دفعة ٣٠ % // عند التسليم دفعة ١٠ %',
  });

  Map<String, dynamic> toJson() => {
        'baselineBrownReflectiveGlassPricePerM2':
            baselineBrownReflectiveGlassPricePerM2,
        'doubleSpacerPricePerMeter': doubleSpacerPricePerMeter,
        'georgianBarPricePerMeter': georgianBarPricePerMeter,
        'flyScreenPricePerM2': flyScreenPricePerM2,
        'shutterPricePerM2': shutterPricePerM2,
        'exhaustFanPrice': exhaustFanPrice,
        'defaultArchPrice': defaultArchPrice,
        'defaultStockBarLengthCm': defaultStockBarLengthCm,
        'defaultSawKerfMm': defaultSawKerfMm,
        'enforceMinimumOneSquareMeter': enforceMinimumOneSquareMeter,
        'companyName': companyName,
        'companySubtitle': companySubtitle,
        'companyPhones': companyPhones,
        'companyAddress': companyAddress,
        'pdfNoteLine1': pdfNoteLine1,
        'pdfNoteLine2': pdfNoteLine2,
        'pdfNoteLine3': pdfNoteLine3,
        'pdfNoteLine4': pdfNoteLine4,
        'pdfNoteLine5': pdfNoteLine5,
        'pdfNoteLine6': pdfNoteLine6,
        'termsAndConditions': termsAndConditions,
      };

  factory PricingSettings.fromJson(Map<String, dynamic> json) => PricingSettings(
        baselineBrownReflectiveGlassPricePerM2:
            (json['baselineBrownReflectiveGlassPricePerM2'] as num?)
                    ?.toDouble() ??
                600.0,
        doubleSpacerPricePerMeter:
            (json['doubleSpacerPricePerMeter'] as num?)?.toDouble() ?? 150.0,
        georgianBarPricePerMeter:
            (json['georgianBarPricePerMeter'] as num?)?.toDouble() ?? 85.0,
        flyScreenPricePerM2:
            (json['flyScreenPricePerM2'] as num?)?.toDouble() ?? 250.0,
        shutterPricePerM2:
            (json['shutterPricePerM2'] as num?)?.toDouble() ?? 1800.0,
        exhaustFanPrice:
            (json['exhaustFanPrice'] as num?)?.toDouble() ?? 350.0,
        defaultArchPrice:
            (json['defaultArchPrice'] as num?)?.toDouble() ?? 600.0,
        defaultStockBarLengthCm:
            (json['defaultStockBarLengthCm'] as num?)?.toDouble() ?? 600.0,
        defaultSawKerfMm:
            (json['defaultSawKerfMm'] as num?)?.toDouble() ?? 4.0,
        enforceMinimumOneSquareMeter:
            json['enforceMinimumOneSquareMeter'] ?? true,
        companyName: json['companyName'] ?? 'شركة الحافظ',
        companySubtitle: json['companySubtitle'] ??
            'للمطابخ الألومنيوم والخشب وجميع أعمال الأخشاب والواجهات الزجاجية',
        companyPhones: json['companyPhones'] ?? '01000000000 - 01200000000',
        companyAddress: json['companyAddress'] ?? 'جمهورية مصر العربية',
        pdfNoteLine1:
            json['pdfNoteLine1'] ?? 'ملحوظة هامة : السعر لا يشمل النقل والمشال',
        pdfNoteLine2: json['pdfNoteLine2'] ??
            'نوع القطاع Emapen الحاصل على شهادة الايزو ISO 9001 + جميع الاكسسوارات تركية الصنع',
        pdfNoteLine3: json['pdfNoteLine3'] ??
            'ضمان ٢٠ سنة على القطاع + ٥ أعوام على الاكسسوارات',
        pdfNoteLine4:
            json['pdfNoteLine4'] ?? 'القطاعات كلها مدعمة بكاوتش مدمج بها',
        pdfNoteLine5: json['pdfNoteLine5'] ??
            'القطاعات كلها مدعمة بحديد مجلفن سماكة ١.٢٥ ملل من الداخل',
        pdfNoteLine6: json['pdfNoteLine6'] ?? 'الاسعار غير شاملة الضريبة',
        termsAndConditions: json['termsAndConditions'] ??
            'عند التعاقد دفعة ٦٠ % // عند التوريد دفعة ٣٠ % // عند التسليم دفعة ١٠ %',
      );
}

/// عنصر شباك أو باب في الورشة الذكية ومقايسة العميل
class ClientWindowItem {
  String id;
  String label;
  String unitType; // شباك | باب
  String openType; // جرار | مفصلي | قلاب | ثابت
  String barType; // ببار | بدون بار | بار مقلوب | تجميع
  String openDirection; // يمين للداخل | شمال للداخل | يمين للخارج | شمال للخارج | قلاب لأعلى
  String sectorId;
  String sectorName;
  String customPdfDescription; // التوصيف المطبوع في عمود "توصيف" بملف الـ PDF
  double sectorPricePerM2; // السعر الافتراضي للمتر المسطح (محسوباً على الزجاج العاكس البني كـ Default)
  bool isCombinedMeterPrice; // إذا كان true لا تضاف فروق ترقية الزجاج (للنموذج الثابت فقط)
  String sectorColor; // بيج | أسود | أبيض | رمادي | خشابي | فضي | شامبين
  double widthCm;
  double heightCm;
  int quantity;
  int sashCount;
  int trackCount; // 2 أو 3 سكة للجرار
  bool hasFlyScreen; // بسلك / بدون سلك
  bool hasPanda; // نظام الباندا في الشباك المفصلي (2 درفة أمامية زجاج + 2 درفة خلفية سلك، والمتر × 1.5)
  bool hasShutter; // شيش حصيرة

  // خصائص قسم الأبواب (كعب الباب، عارضة الوسط، والحشو السفلي)
  bool hasDoorKickplate; // كعب باب سفلي عريض
  double doorBottomKickHeightCm; // ارتفاع الجزء السفلي للباب (مثلاً 70 سم)
  bool hasDoorMiddleMullion; // عارضة وسط الباب (سؤاس وسط)
  String doorBottomPanelType; // فايبر / شرائح ألومنيوم | زجاج

  // خصائص الدوران العلوي (القوس) للشباك
  bool hasArch; // هل يوجد دوران علوي في هذا الشباك؟
  double archWidthCm; // عرض الدوران (الوتر) بالسنتيمتر
  double archHeightCm; // ارتفاع / سقوط الدوران من أقصى نقطة في منتصف عرض الشباك (سم)
  double archPriceEgp; // سعر الدوران المنفصل لهذا الشباك (يضاف على سعر الشباك في عرض السعر)

  // الثوابت في جميع الاتجاهات (شمال، يمين، فوق، تحت) مع مقاسها وعدد تقسيماتها
  bool hasTopFixed;
  double topFixedHeightCm;
  int topFixedSplits; // عدد أجزاء الثابت العلوي (1 = قطعة واحدة، 2 = مقسوم قطعتين...)

  bool hasBottomFixed;
  double bottomFixedHeightCm;
  int bottomFixedSplits;

  bool hasRightFixed;
  double rightFixedWidthCm;
  int rightFixedSplits;

  bool hasLeftFixed;
  double leftFixedWidthCm;
  int leftFixedSplits;

  // الشفاط (يركب في الثابت، وإذا كان الثابت مقسماً يوضع في جزء واحد منه)
  bool hasExhaustFan;
  String exhaustFanShape; // دائري | مربع
  double exhaustFanDiameterCm;
  String exhaustFanPosition; // في الثابت العلوي | في الثابت السفلي | في الثابت اليمين | في الثابت الشمال
  int exhaustFanPartIndex; // رقم الجزء داخل الثابت المقسم (0 = الجزء الأول، 1 = الجزء الثاني...)

  // الزجاج (الافتراضي: عاكس بني 6 مم)
  bool hasGlass;
  bool isDoubleGlass;
  String? glass1Id;
  String glass1Name;
  double glass1PricePerM2;
  String? glass2Id;
  String glass2Name; // الطبقة الثانية في الزجاج الدابل
  double glass2PricePerM2;
  double baselineGlassPricePerM2; // سعر الزجاج العاكس البني الافتراضي (للحماية من نقص السعر وحساب الترقية)
  double spacerPricePerMeter; // سعر السبيسر من قائمة التسعير

  // الجورجيا (الأشكال والتقسيمات الجمالية بين الزجاج)
  bool hasGeorgianBars;
  double georgianMetersPerWindow;
  double georgianPricePerMeter;

  ClientWindowItem({
    required this.id,
    required this.label,
    this.unitType = 'شباك',
    this.openType = 'جرار',
    this.barType = 'ببار',
    this.openDirection = 'يمين للداخل',
    required this.sectorId,
    required this.sectorName,
    this.customPdfDescription = '',
    required this.sectorPricePerM2,
    this.isCombinedMeterPrice = false,
    this.sectorColor = 'بيج',
    required this.widthCm,
    required this.heightCm,
    this.quantity = 1,
    this.sashCount = 2,
    this.trackCount = 2,
    this.hasFlyScreen = true,
    this.hasPanda = false,
    this.hasShutter = false,
    this.hasDoorKickplate = true,
    this.doorBottomKickHeightCm = 75.0,
    this.hasDoorMiddleMullion = true,
    this.doorBottomPanelType = 'حشو فايبر / شرائح ألومنيوم',
    this.hasArch = false,
    double? archWidthCm,
    this.archHeightCm = 25.0,
    this.archPriceEgp = 600.0,
    this.hasTopFixed = false,
    this.topFixedHeightCm = 40.0,
    this.topFixedSplits = 1,
    this.hasBottomFixed = false,
    this.bottomFixedHeightCm = 40.0,
    this.bottomFixedSplits = 1,
    this.hasRightFixed = false,
    this.rightFixedWidthCm = 40.0,
    this.rightFixedSplits = 1,
    this.hasLeftFixed = false,
    this.leftFixedWidthCm = 40.0,
    this.leftFixedSplits = 1,
    this.hasExhaustFan = false,
    this.exhaustFanShape = 'دائري',
    this.exhaustFanDiameterCm = 25.0,
    this.exhaustFanPosition = 'في الثابت العلوي',
    this.exhaustFanPartIndex = 0,
    this.hasGlass = true,
    this.isDoubleGlass = false,
    this.glass1Id,
    this.glass1Name = 'عاكس بني 6 مم',
    this.glass1PricePerM2 = 600.0,
    this.glass2Id,
    this.glass2Name = 'شفاف 6 مم',
    this.glass2PricePerM2 = 450.0,
    this.baselineGlassPricePerM2 = 600.0,
    this.spacerPricePerMeter = 150.0,
    this.hasGeorgianBars = false,
    this.georgianMetersPerWindow = 0.0,
    this.georgianPricePerMeter = 85.0,
  }) : archWidthCm = archWidthCm ?? widthCm;

  /// صافي عرض الجزء المتحرك بعد خصم الثابت اليمين والثابت الشمال
  double get netOperableWidthCm {
    double w = widthCm;
    if (hasRightFixed) w -= rightFixedWidthCm;
    if (hasLeftFixed) w -= leftFixedWidthCm;
    return math.max(20.0, w);
  }

  /// صافي ارتفاع الجزء المتحرك بعد خصم الثابت العلوي والثابت السفلي
  double get netOperableHeightCm {
    double h = heightCm;
    if (hasTopFixed) h -= topFixedHeightCm;
    if (hasBottomFixed) h -= bottomFixedHeightCm;
    return math.max(20.0, h);
  }

  /// حساب نصف قطر الدوران الهندسي R بالسنتيمتر: R = (h / 2) + (w^2 / (8 * h))
  double get archRadiusCm {
    final double w = archWidthCm > 0 ? archWidthCm : widthCm;
    final double h = archHeightCm;
    if (h <= 0 || w <= 0) return 0.0;
    return (h / 2.0) + ((w * w) / (8.0 * h));
  }

  /// طول قوس الدوران الصافي بالسنتيمتر
  double get archNetArcLengthCm {
    final double w = archWidthCm > 0 ? archWidthCm : widthCm;
    final double r = archRadiusCm;
    if (r <= 0 || w > 2 * r) return w;
    final double angleRad = 2.0 * math.asin((w / (2.0 * r)).clamp(-1.0, 1.0));
    return r * angleRad;
  }

  /// هل يطبق نظام التركيبة المشتركة (شباك جرار + ثابت علوي + قطاع إتش H-Profile + بار منفصل حوالين داير)؟
  bool get usesSlidingWithTopFixedHConnector =>
      openType == 'جرار' && hasTopFixed && topFixedHeightCm > 0;

  /// فحص ما إذا كان مقاس الشفاط مناسباً ومضبوطاً لمقاس الثابت المحدد (لتفعيل المؤشر الأخضر الذكي)
  bool isExhaustFanSizeOptimal({double fixedDeductCm = 6.4}) {
    if (!hasExhaustFan || exhaustFanDiameterCm <= 0) return false;
    double partW = widthCm;
    double partH = topFixedHeightCm;
    if (exhaustFanPosition.contains('العلوي')) {
      partW = widthCm / math.max(1, topFixedSplits);
      partH = topFixedHeightCm;
    } else if (exhaustFanPosition.contains('السفلي')) {
      partW = widthCm / math.max(1, bottomFixedSplits);
      partH = bottomFixedHeightCm;
    } else if (exhaustFanPosition.contains('اليمين')) {
      partW = rightFixedWidthCm;
      partH = netOperableHeightCm / math.max(1, rightFixedSplits);
    } else if (exhaustFanPosition.contains('الشمال')) {
      partW = leftFixedWidthCm;
      partH = netOperableHeightCm / math.max(1, leftFixedSplits);
    }
    final double minFixedDim = math.min(partW, partH);
    final double netInnerGlassDim = minFixedDim - fixedDeductCm;
    // يكون مقاس الشفاط مضبوطاً ومثالياً إذا كان >= 15 سم وأصغر من أو يساوي صافي فتحة الثابت بدون تجاوز
    return exhaustFanDiameterCm >= 15.0 &&
        exhaustFanDiameterCm <= netInnerGlassDim + 0.5;
  }

  /// أقصى مقاس مسموح للشفاط داخل الثابت المختار بالسنتيمتر
  double maxAllowedExhaustFanDiameterCm({double fixedDeductCm = 6.4}) {
    double partW = widthCm;
    double partH = topFixedHeightCm;
    if (exhaustFanPosition.contains('العلوي')) {
      partW = widthCm / math.max(1, topFixedSplits);
      partH = topFixedHeightCm;
    } else if (exhaustFanPosition.contains('السفلي')) {
      partW = widthCm / math.max(1, bottomFixedSplits);
      partH = bottomFixedHeightCm;
    } else if (exhaustFanPosition.contains('اليمين')) {
      partW = rightFixedWidthCm;
      partH = netOperableHeightCm / math.max(1, rightFixedSplits);
    } else if (exhaustFanPosition.contains('الشمال')) {
      partW = leftFixedWidthCm;
      partH = netOperableHeightCm / math.max(1, leftFixedSplits);
    }
    return math.max(10.0, math.min(partW, partH) - fixedDeductCm);
  }

  /// مساحة الشباك الواحد بالمتر المربع (العرض × الطول)
  double singleWindowAreaM2({bool minOneM2 = true}) {
    final double rawArea = (widthCm / 100.0) * (heightCm / 100.0);
    if (minOneM2 && rawArea < 1.0) {
      return 1.0;
    }
    return rawArea;
  }

  /// المساحة المطبوعة في جدول عرض السعر (منزلتين عشريتين)
  double displaySingleAreaM2({bool minOneM2 = true}) {
    return double.parse(
        singleWindowAreaM2(minOneM2: minOneM2).toStringAsFixed(2));
  }

  double totalAreaM2({bool minOneM2 = true}) =>
      singleWindowAreaM2(minOneM2: minOneM2) * quantity;

  double displayTotalAreaM2({bool minOneM2 = true}) =>
      displaySingleAreaM2(minOneM2: minOneM2) * quantity;

  /// معامل نظام الباندا: في حالة اختيار الباندا للمفصلي يُضرب سعر متر القطاع الأساسي في 1.5 (مرة ونصف)
  double get pandaMultiplier =>
      (hasPanda && (openType.contains('مفصلي') || openType.contains('قلاب')))
          ? 1.5
          : 1.0;

  /// حساب فارق ترقية الزجاج والسبيسر فوق الزجاج الافتراضي ("العاكس البني"):
  /// - السعر الأساسي للمتر محسوب دائماً على "العاكس البني" (baselineGlassPricePerM2).
  /// - إذا اختار العميل زجاجاً أرخص من العاكس البني: يرفض النظام خصم الفارق (0 جنيه خصم) ولا يقل السعر عن الديفولت.
  /// - إذا اختار زجاجاً أغلى (مثل عاكس أزرق) أو دبل طبقتين + سبيسر: يضاف الفارق وتكلفة الطبقة الثانية والسبيسر فوق سعر المتر.
  double glassUpgradeDiffPerM2() {
    if (isCombinedMeterPrice || !hasGlass) return 0.0;
    final double baseRef =
        baselineGlassPricePerM2 > 0 ? baselineGlassPricePerM2 : 600.0;

    if (!isDoubleGlass) {
      // زجاج سنجل: إذا كان أغلى من العاكس البني نضيف الفارق فقط، وإذا كان أرخص لا نخصم شيئاً (حماية السعر الأدنى)
      return math.max(0.0, glass1PricePerM2 - baseRef);
    } else {
      // زجاج دبل: الطبقة الأولى محمية بحد أدنى العاكس البني + تضاف الطبقة الثانية بالكامل + يضاف سعر السبيسر
      final double layer1Diff = math.max(0.0, glass1PricePerM2 - baseRef);
      return layer1Diff + glass2PricePerM2 + spacerPricePerMeter;
    }
  }

  /// سعر المتر النهائي المطبوع في عمود "سعر المتر" بعد تطبيق معامل الباندا (× 1.5) وإضافة فارق ترقية الزجاج والسبيسر
  double effectiveMeterPrice(SectorProfile? sector) {
    final double baseSectorPriceWithPanda = sectorPricePerM2 * pandaMultiplier;
    return baseSectorPriceWithPanda + glassUpgradeDiffPerM2();
  }

  /// تكلفة أعواد الجورجيا المضافة بين الزجاج
  double calculateGeorgianCost() {
    if (!hasGeorgianBars || georgianMetersPerWindow <= 0) {
      return 0.0;
    }
    return georgianMetersPerWindow * quantity * georgianPricePerMeter;
  }

  /// تكلفة الدوران (القوس) المضافة للشباك بشكل منفصل (سعر الدوران × عدد الشبابيك)
  double calculateArchTotalCost() {
    if (!hasArch || archPriceEgp <= 0) return 0.0;
    return archPriceEgp * quantity;
  }

  /// إجمالي سعر البند النهائي = (المساحة × سعر المتر النهائي) × العدد + تكلفة الجورجيا + تكلفة الدوران للشباك
  double calculateTotalCost(SectorProfile? sector, {bool minOneM2 = true}) {
    final double singleArea = singleWindowAreaM2(minOneM2: minOneM2);
    final double meterPrice = effectiveMeterPrice(sector);
    final double singleUnitBaseCost = (singleArea * meterPrice).roundToDouble();
    return (singleUnitBaseCost * quantity) +
        calculateGeorgianCost().roundToDouble() +
        calculateArchTotalCost().roundToDouble();
  }

  /// التوصيف المطبوع في عمود "توصيف" في ملف الـ PDF
  String pdfDescriptionText(SectorProfile? sector) {
    if (customPdfDescription.trim().isNotEmpty) {
      return customPdfDescription.trim();
    }
    final String shortSec = sector?.shortPdfName ?? sectorName;
    final String sCount = _toArabicDigits('$sashCount');
    final String unitPrefix = unitType == 'باب' ? 'باب ' : '';
    final String pandaTag =
        (hasPanda && openType.contains('مفصلي')) ? ' باندا' : '';
    final String archTag =
        hasArch ? '\n+ دوران (${archPriceEgp.toStringAsFixed(0)}ج)' : '';
    return '$unitPrefix$openType$pandaTag $sCount ضلفة\n$shortSec$archTag';
  }

  static String _toArabicDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String out = input;
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(en[i], ar[i]);
    }
    return out;
  }

  /// النص المطبوع في عمود "نوع الزجاج" في ملف الـ PDF
  String get glassSummaryText {
    if (!hasGlass) return 'بدون زجاج';
    if (isDoubleGlass &&
        glass2Name.trim().isNotEmpty &&
        !glass1Name.contains('على')) {
      final String g1 = glass1Name
          .replaceAll('\n', ' ')
          .replaceAll('سنجل', '')
          .replaceAll('دبل', '')
          .replaceAll('(الافتراضي الأساسي)', '')
          .trim();
      final String g2 = glass2Name
          .replaceAll('\n', ' ')
          .replaceAll('سنجل', '')
          .replaceAll('دبل', '')
          .replaceAll('(الافتراضي الأساسي)', '')
          .trim();
      return 'دبل\n$g1\nعلى $g2';
    }
    return glass1Name.replaceAll('(الافتراضي الأساسي)', '').trim();
  }

  String get configurationSummary {
    final List<String> list = [];
    final String pandaStr =
        (hasPanda && openType.contains('مفصلي'))
            ? ' (باندا: 2 زجاج أمامي + 2 سلك خلفي ×1.5)'
            : '';
    list.add('$unitType $openType$pandaStr $sashCount ضلفة');
    if (hasArch) {
      list.add(
          'دوران علوي (وتر ${archWidthCm.toStringAsFixed(0)}×ارتفاع ${archHeightCm.toStringAsFixed(0)} سم - ${archPriceEgp.toStringAsFixed(0)} ج.م)');
    }
    if (hasTopFixed) {
      list.add(
          'ثابت فوق (${topFixedHeightCm.toStringAsFixed(0)} سم${topFixedSplits > 1 ? " مقسوم $topFixedSplits" : ""}${usesSlidingWithTopFixedHConnector ? " + قطاع إتش وبار منفصل" : ""})');
    }
    if (hasBottomFixed) {
      list.add(
          'ثابت تحت (${bottomFixedHeightCm.toStringAsFixed(0)} سم${bottomFixedSplits > 1 ? " مقسوم $bottomFixedSplits" : ""})');
    }
    if (hasRightFixed) {
      list.add(
          'ثابت يمين (${rightFixedWidthCm.toStringAsFixed(0)} سم${rightFixedSplits > 1 ? " مقسوم $rightFixedSplits" : ""})');
    }
    if (hasLeftFixed) {
      list.add(
          'ثابت شمال (${leftFixedWidthCm.toStringAsFixed(0)} سم${leftFixedSplits > 1 ? " مقسوم $leftFixedSplits" : ""})');
    }
    if (hasExhaustFan) {
      list.add(
          'شفاط $exhaustFanPosition (جزء ${exhaustFanPartIndex + 1} - ${exhaustFanDiameterCm.toStringAsFixed(0)} سم)');
    }
    if (hasGeorgianBars && georgianMetersPerWindow > 0) {
      list.add('جورجيا (${georgianMetersPerWindow.toStringAsFixed(1)} م)');
    }
    return list.join(' • ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'unitType': unitType,
        'openType': openType,
        'barType': barType,
        'openDirection': openDirection,
        'sectorId': sectorId,
        'sectorName': sectorName,
        'customPdfDescription': customPdfDescription,
        'sectorPricePerM2': sectorPricePerM2,
        'isCombinedMeterPrice': isCombinedMeterPrice,
        'sectorColor': sectorColor,
        'widthCm': widthCm,
        'heightCm': heightCm,
        'quantity': quantity,
        'sashCount': sashCount,
        'trackCount': trackCount,
        'hasFlyScreen': hasFlyScreen,
        'hasPanda': hasPanda,
        'hasShutter': hasShutter,
        'hasDoorKickplate': hasDoorKickplate,
        'doorBottomKickHeightCm': doorBottomKickHeightCm,
        'hasDoorMiddleMullion': hasDoorMiddleMullion,
        'doorBottomPanelType': doorBottomPanelType,
        'hasArch': hasArch,
        'archWidthCm': archWidthCm,
        'archHeightCm': archHeightCm,
        'archPriceEgp': archPriceEgp,
        'hasTopFixed': hasTopFixed,
        'topFixedHeightCm': topFixedHeightCm,
        'topFixedSplits': topFixedSplits,
        'hasBottomFixed': hasBottomFixed,
        'bottomFixedHeightCm': bottomFixedHeightCm,
        'bottomFixedSplits': bottomFixedSplits,
        'hasRightFixed': hasRightFixed,
        'rightFixedWidthCm': rightFixedWidthCm,
        'rightFixedSplits': rightFixedSplits,
        'hasLeftFixed': hasLeftFixed,
        'leftFixedWidthCm': leftFixedWidthCm,
        'leftFixedSplits': leftFixedSplits,
        'hasExhaustFan': hasExhaustFan,
        'exhaustFanShape': exhaustFanShape,
        'exhaustFanDiameterCm': exhaustFanDiameterCm,
        'exhaustFanPosition': exhaustFanPosition,
        'exhaustFanPartIndex': exhaustFanPartIndex,
        'hasGlass': hasGlass,
        'isDoubleGlass': isDoubleGlass,
        'glass1Id': glass1Id,
        'glass1Name': glass1Name,
        'glass1PricePerM2': glass1PricePerM2,
        'glass2Id': glass2Id,
        'glass2Name': glass2Name,
        'glass2PricePerM2': glass2PricePerM2,
        'baselineGlassPricePerM2': baselineGlassPricePerM2,
        'spacerPricePerMeter': spacerPricePerMeter,
        'hasGeorgianBars': hasGeorgianBars,
        'georgianMetersPerWindow': georgianMetersPerWindow,
        'georgianPricePerMeter': georgianPricePerMeter,
      };

  factory ClientWindowItem.fromJson(Map<String, dynamic> json) =>
      ClientWindowItem(
        id: json['id'] ?? '',
        label: json['label'] ?? 'شباك',
        unitType: json['unitType'] ?? 'شباك',
        openType: json['openType'] ?? 'جرار',
        barType: json['barType'] ?? 'ببار',
        openDirection: json['openDirection'] ?? 'يمين للداخل',
        sectorId: json['sectorId'] ?? '',
        sectorName: json['sectorName'] ?? '',
        customPdfDescription: json['customPdfDescription']?.toString() ?? '',
        sectorPricePerM2:
            (json['sectorPricePerM2'] as num?)?.toDouble() ?? 5500.0,
        isCombinedMeterPrice: json['isCombinedMeterPrice'] ?? false,
        sectorColor: json['sectorColor']?.toString() ?? 'بيج',
        widthCm: (json['widthCm'] as num?)?.toDouble() ?? 100.0,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 100.0,
        quantity: json['quantity'] ?? 1,
        sashCount: json['sashCount'] ?? 2,
        trackCount: json['trackCount'] ?? 2,
        hasFlyScreen: json['hasFlyScreen'] ?? true,
        hasPanda: json['hasPanda'] ?? false,
        hasShutter: json['hasShutter'] ?? false,
        hasDoorKickplate: json['hasDoorKickplate'] ?? true,
        doorBottomKickHeightCm:
            (json['doorBottomKickHeightCm'] as num?)?.toDouble() ?? 75.0,
        hasDoorMiddleMullion: json['hasDoorMiddleMullion'] ?? true,
        doorBottomPanelType:
            json['doorBottomPanelType'] ?? 'حشو فايبر / شرائح ألومنيوم',
        hasArch: json['hasArch'] ?? false,
        archWidthCm: (json['archWidthCm'] as num?)?.toDouble() ??
            (json['widthCm'] as num?)?.toDouble() ??
            100.0,
        archHeightCm: (json['archHeightCm'] as num?)?.toDouble() ?? 25.0,
        archPriceEgp: (json['archPriceEgp'] as num?)?.toDouble() ?? 600.0,
        hasTopFixed: json['hasTopFixed'] ?? false,
        topFixedHeightCm:
            (json['topFixedHeightCm'] as num?)?.toDouble() ?? 40.0,
        topFixedSplits: (json['topFixedSplits'] as num?)?.toInt() ?? 1,
        hasBottomFixed: json['hasBottomFixed'] ?? false,
        bottomFixedHeightCm:
            (json['bottomFixedHeightCm'] as num?)?.toDouble() ?? 40.0,
        bottomFixedSplits: (json['bottomFixedSplits'] as num?)?.toInt() ?? 1,
        hasRightFixed: json['hasRightFixed'] ?? false,
        rightFixedWidthCm:
            (json['rightFixedWidthCm'] as num?)?.toDouble() ?? 40.0,
        rightFixedSplits: (json['rightFixedSplits'] as num?)?.toInt() ?? 1,
        hasLeftFixed: json['hasLeftFixed'] ?? false,
        leftFixedWidthCm:
            (json['leftFixedWidthCm'] as num?)?.toDouble() ?? 40.0,
        leftFixedSplits: (json['leftFixedSplits'] as num?)?.toInt() ?? 1,
        hasExhaustFan: json['hasExhaustFan'] ?? false,
        exhaustFanShape: json['exhaustFanShape'] ?? 'دائري',
        exhaustFanDiameterCm:
            (json['exhaustFanDiameterCm'] as num?)?.toDouble() ?? 25.0,
        exhaustFanPosition:
            json['exhaustFanPosition'] ?? 'في الثابت العلوي',
        exhaustFanPartIndex:
            (json['exhaustFanPartIndex'] as num?)?.toInt() ?? 0,
        hasGlass: json['hasGlass'] ?? true,
        isDoubleGlass: json['isDoubleGlass'] ?? false,
        glass1Id: json['glass1Id'],
        glass1Name: json['glass1Name'] ?? 'عاكس بني 6 مم',
        glass1PricePerM2:
            (json['glass1PricePerM2'] as num?)?.toDouble() ?? 600.0,
        glass2Id: json['glass2Id'],
        glass2Name: json['glass2Name'] ?? 'شفاف 6 مم',
        glass2PricePerM2:
            (json['glass2PricePerM2'] as num?)?.toDouble() ?? 450.0,
        baselineGlassPricePerM2:
            (json['baselineGlassPricePerM2'] as num?)?.toDouble() ?? 600.0,
        spacerPricePerMeter:
            (json['spacerPricePerMeter'] as num?)?.toDouble() ?? 150.0,
        hasGeorgianBars: json['hasGeorgianBars'] ?? false,
        georgianMetersPerWindow:
            (json['georgianMetersPerWindow'] as num?)?.toDouble() ?? 0.0,
        georgianPricePerMeter:
            (json['georgianPricePerMeter'] as num?)?.toDouble() ?? 85.0,
      );
}

/// سجل مقايسة وعرض سعر العميل وطلبية الورشة
class ClientRecord {
  String id;
  String clientName;
  String clientPhone;
  String clientAddress;
  String createdAt;
  String notes;
  double discountAmount;
  double depositAmount;
  double archCost;
  List<ClientWindowItem> items;

  ClientRecord({
    required this.id,
    required this.clientName,
    this.clientPhone = '',
    this.clientAddress = '',
    required this.createdAt,
    this.notes = '',
    this.discountAmount = 0.0,
    this.depositAmount = 0.0,
    this.archCost = 0.0,
    required this.items,
  });

  /// إجمالي أسعار الدورانات المضافة داخل الشبابيك + قيمة الدورانات الإضافية العامة
  double get totalArchCostAll {
    double sum = archCost;
    for (final it in items) {
      sum += it.calculateArchTotalCost();
    }
    return sum;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientAddress': clientAddress,
        'createdAt': createdAt,
        'notes': notes,
        'discountAmount': discountAmount,
        'depositAmount': depositAmount,
        'archCost': archCost,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory ClientRecord.fromJson(Map<String, dynamic> json) => ClientRecord(
        id: json['id'] ?? '',
        clientName: json['clientName'] ?? '',
        clientPhone: json['clientPhone'] ?? '',
        clientAddress: json['clientAddress'] ?? '',
        createdAt: json['createdAt'] ?? '',
        notes: json['notes'] ?? '',
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
        depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0.0,
        archCost: (json['archCost'] as num?)?.toDouble() ?? 0.0,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) =>
                    ClientWindowItem.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

/// خطة تقطيع العود القياسي (600 سم أو 650 سم)
class BarCutPlan {
  int barNumber;
  int get barIndex => barNumber;
  set barIndex(int v) => barNumber = v;

  double barLengthCm;
  double kerfMm;

  List<double> cutsCm;
  List<double> get cutPiecesCm => cutsCm;
  set cutPiecesCm(List<double> v) => cutsCm = v;

  double usedLengthCm;
  double wasteLengthCm;
  double wastePercentage;

  BarCutPlan({
    int? barNumber,
    int? barIndex,
    this.barLengthCm = 600.0,
    this.kerfMm = 4.0,
    List<double>? cutsCm,
    List<double>? cutPiecesCm,
    required this.usedLengthCm,
    required this.wasteLengthCm,
    required this.wastePercentage,
  })  : barNumber = barNumber ?? barIndex ?? 1,
        cutsCm = cutsCm ?? cutPiecesCm ?? [];
}

/// ملخص تجميع وتقطيع بروفايل واحد في حساب الطلبية (الورشة الذكية)
/// ملاحظة مهمة: يتم جمع طول وعرض الدرفة (أو الحلق) التي تشترك في نفس البروفايل والـ SVG في بند واحد مشترك!
class AggregatedProfileOrder {
  final String sectorName;
  final String partName;
  final String role;
  final String? svgAssetPath;
  final Map<double, int> lengthCounts; // الطول بالسنتيمتر -> العدد
  final List<String> dimensionBreakdownLabels; // تفاصيل الأطوال والعروض المدمجة (مثلاً: عرض الدرفة 72 سم × 4 + طول الدرفة 113 سم × 4)
  final List<double> allPiecesCm;
  final List<BarCutPlan> barPlans;

  AggregatedProfileOrder({
    required this.sectorName,
    required this.partName,
    required this.role,
    this.svgAssetPath,
    required this.lengthCounts,
    this.dimensionBreakdownLabels = const [],
    required this.allPiecesCm,
    required this.barPlans,
  });

  int get totalBarsNeeded => barPlans.length;
  int get totalPiecesCount => allPiecesCm.length;
}
