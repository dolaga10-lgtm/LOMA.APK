import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workshop_models.dart';

class WorkshopStorage extends ChangeNotifier {
  static const String _kSectorsKey = 'hafez_sw_sectors_v14';
  static const String _kGlassesKey = 'hafez_sw_glasses_v14';
  static const String _kAccessoriesKey = 'hafez_sw_accessories_v14';
  static const String _kSettingsKey = 'hafez_sw_pricing_settings_v14';
  static const String _kClientsKey = 'hafez_sw_clients_records_v14';

  List<SectorProfile> sectors = [];
  List<GlassTypeItem> glassTypes = [];
  List<AccessoryPriceItem> accessories = [];
  PricingSettings pricingSettings = PricingSettings();
  List<ClientRecord> clients = [];
  bool isLoaded = false;

  /// ترتيب مجموعات الشركات (مع استبدال قطاع السعد بقطاع السلام، والمكينات الشارقة بقطاعات الشريف)
  static const List<Map<String, String>> companyGroupsOrder = [
    {
      'name': 'قطاعات السلام (PS)',
      'logo': 'assets/images/windows/systems/s000.png',
      'subtitle': 'PS 9600 • PS 6600 • PS 5600 • PS 4800',
      'catalogUrl': 'https://drive.google.com/drive/search?q=PS+aluminium+catalogue',
    },
    {
      'name': 'قطاعات الشريف',
      'logo': 'assets/images/windows/systems/s001.png',
      'subtitle': 'جامبو 100 • تانجو 60 • تندو 120 • تيمبو 84 • سوناتا 45 • نانو 50',
      'catalogUrl': 'https://mac-eg.com/',
    },
    {
      'name': 'فالف القباري (VALVE)',
      'logo': 'assets/images/windows/systems/s002.png',
      'subtitle': 'فالف V170 • فالف V140 • فالف MV100',
      'catalogUrl': 'https://alkabbary.com/',
    },
    {
      'name': 'الدولية 21 - ماكسيم',
      'logo': 'assets/images/windows/systems/s003.png',
      'subtitle': 'ماكسيم E777 • ماكسيم E105 • إيكونومي E47 • إيكونومي E37',
      'catalogUrl': 'https://dawlia21.com/',
    },
    {
      'name': 'قطاعات ألوميل (AluMil)',
      'logo': 'assets/images/windows/systems/s004.png',
      'subtitle': 'M12000 • M9200 • M900 • M9400 • M940',
      'catalogUrl': 'https://www.alumil.com/egypt/ar/homeowners/products',
    },
    {
      'name': 'إيجماس - فولكانو (Volcano)',
      'logo': 'assets/images/windows/systems/s007.jpg',
      'subtitle': 'فولكانو V120 • فولكانو V70 • فولكانو V44',
      'catalogUrl': 'https://egmas.com/',
    },
    {
      'name': 'قطاعات UPVC المصري (Emapen)',
      'logo': 'assets/images/windows/systems/upvc_eg.jpg',
      'subtitle': 'UPVC كبير جرار • UPVC صغير • UPVC مفصلي وقلاب',
      'catalogUrl': 'https://emapen.com/',
    },
    {
      'name': 'قطاعات UPVC المستورد',
      'logo': 'assets/images/windows/systems/s005.png',
      'subtitle': 'وينتك Wintech • كومبن Kompen • بيمابن Pimapen',
      'catalogUrl': 'https://www.wintech.com.tr/',
    },
  ];

  /// إرجاع نوع الزجاج الافتراضي الأساسي ("عاكس بني 6 مم") الذي يُبنى عليه سعر المتر المسطح
  GlassTypeItem get defaultBaselineBrownGlass {
    for (final g in glassTypes) {
      if (g.isDefaultBaseline || g.name.contains('عاكس بني')) {
        return g;
      }
    }
    return glassTypes.isNotEmpty
        ? glassTypes.first
        : GlassTypeItem(
            id: 'g_single_ref_brown_6',
            name: 'عاكس بني 6 مم (الافتراضي الأساسي)',
            pricePerSquareMeter: 600.0,
            isDefaultBaseline: true,
          );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final String? sectorsRaw = prefs.getString(_kSectorsKey);
    if (sectorsRaw != null && sectorsRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(sectorsRaw);
        sectors = list
            .map((e) => SectorProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        sectors = _allStandardSectors();
      }
    } else {
      sectors = _allStandardSectors();
    }

    final String? glassesRaw = prefs.getString(_kGlassesKey);
    if (glassesRaw != null && glassesRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(glassesRaw);
        glassTypes = list
            .map((e) => GlassTypeItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        glassTypes = _defaultGlassTypes();
      }
    } else {
      glassTypes = _defaultGlassTypes();
    }

    final String? accRaw = prefs.getString(_kAccessoriesKey);
    if (accRaw != null && accRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(accRaw);
        accessories = list
            .map((e) =>
                AccessoryPriceItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        accessories = _defaultAccessories();
      }
    } else {
      accessories = _defaultAccessories();
    }

    final String? settingsRaw = prefs.getString(_kSettingsKey);
    if (settingsRaw != null && settingsRaw.isNotEmpty) {
      try {
        pricingSettings = PricingSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(settingsRaw)));
      } catch (_) {
        pricingSettings = PricingSettings();
      }
    }

    final String? clientsRaw = prefs.getString(_kClientsKey);
    if (clientsRaw != null && clientsRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(clientsRaw);
        clients = list
            .map((e) => ClientRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        clients = [_sampleAhmedAboElYazeedRecord()];
      }
    } else {
      clients = [_sampleAhmedAboElYazeedRecord()];
    }

    isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kSectorsKey, jsonEncode(sectors.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _kGlassesKey, jsonEncode(glassTypes.map((e) => e.toJson()).toList()));
    await prefs.setString(_kAccessoriesKey,
        jsonEncode(accessories.map((e) => e.toJson()).toList()));
    await prefs.setString(_kSettingsKey, jsonEncode(pricingSettings.toJson()));
    await prefs.setString(
        _kClientsKey, jsonEncode(clients.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  SectorProfile? getSectorById(String id) {
    for (final s in sectors) {
      if (s.id == id) return s;
    }
    return sectors.isNotEmpty ? sectors.first : null;
  }

  Future<void> addOrUpdateSector(SectorProfile sector) async {
    final idx = sectors.indexWhere((e) => e.id == sector.id);
    if (idx >= 0) {
      sectors[idx] = sector;
    } else {
      sectors.insert(0, sector);
    }
    await _saveAll();
  }

  Future<void> deleteSector(String id) async {
    sectors.removeWhere((e) => e.id == id);
    await _saveAll();
  }

  Future<void> updateSectorPrice(String sectorId, double newPrice,
      {double? barPrice, String? catalogUrl}) async {
    final idx = sectors.indexWhere((e) => e.id == sectorId);
    if (idx >= 0) {
      sectors[idx].pricePerSquareMeter = newPrice;
      if (barPrice != null) sectors[idx].barPrice = barPrice;
      if (catalogUrl != null) sectors[idx].catalogUrl = catalogUrl;
      await _saveAll();
    }
  }

  Future<void> addOrUpdateGlassType(GlassTypeItem item) async {
    final idx = glassTypes.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      glassTypes[idx] = item;
    } else {
      glassTypes.add(item);
    }
    if (item.isDefaultBaseline) {
      pricingSettings.baselineBrownReflectiveGlassPricePerM2 =
          item.pricePerSquareMeter;
    }
    await _saveAll();
  }

  Future<void> deleteGlassType(String id) async {
    glassTypes.removeWhere((e) => e.id == id);
    await _saveAll();
  }

  Future<void> addOrUpdateAccessory(AccessoryPriceItem item) async {
    final idx = accessories.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      accessories[idx] = item;
    } else {
      accessories.add(item);
    }
    await _saveAll();
  }

  Future<void> deleteAccessory(String id) async {
    accessories.removeWhere((e) => e.id == id);
    await _saveAll();
  }

  Future<void> updatePricingSettings(PricingSettings newSettings) async {
    pricingSettings = newSettings;
    await _saveAll();
  }

  Future<void> saveClientRecord(ClientRecord record) async {
    final idx = clients.indexWhere((e) => e.id == record.id);
    if (idx >= 0) {
      clients[idx] = record;
    } else {
      clients.insert(0, record);
    }
    await _saveAll();
  }

  Future<void> deleteClientRecord(String clientId) async {
    clients.removeWhere((e) => e.id == clientId);
    await _saveAll();
  }

  /// خوارزمية تقسيم الأعواد القياسية (First-Fit Decreasing)
  static List<BarCutPlan> optimize1DBars({
    required List<double> requiredPiecesCm,
    double stockLengthCm = 600.0,
    double sawKerfMm = 4.0,
  }) {
    final double kerfCm = sawKerfMm / 10.0;
    final List<double> sorted = requiredPiecesCm
        .where((p) => p > 0 && p <= stockLengthCm)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final List<List<double>> bins = [];
    final List<double> binRemaining = [];

    for (final piece in sorted) {
      bool placed = false;
      for (int i = 0; i < bins.length; i++) {
        final double needed = piece + (bins[i].isEmpty ? 0.0 : kerfCm);
        if (binRemaining[i] >= needed - 1e-6) {
          bins[i].add(piece);
          binRemaining[i] = math.max(0.0, binRemaining[i] - needed);
          placed = true;
          break;
        }
      }
      if (!placed) {
        bins.add([piece]);
        binRemaining.add(math.max(0.0, stockLengthCm - piece));
      }
    }

    final List<BarCutPlan> plans = [];
    for (int i = 0; i < bins.length; i++) {
      final double waste = double.parse(binRemaining[i].toStringAsFixed(2));
      final double used =
          double.parse((stockLengthCm - waste).toStringAsFixed(2));
      plans.add(BarCutPlan(
        barNumber: i + 1,
        barLengthCm: stockLengthCm,
        kerfMm: sawKerfMm,
        cutsCm: bins[i],
        usedLengthCm: used,
        wasteLengthCm: waste,
        wastePercentage:
            stockLengthCm > 0 ? (waste / stockLengthCm) * 100 : 0.0,
      ));
    }
    return plans;
  }

  /// توحيد مسمى البروفايل لدمج (عرض) و(ارتفاع) الدرفة أو الحلق أو الباكتة في بند واحد مشترك
  static String _unifyProfilePartName(String rawName) {
    if (rawName.contains('(عرض)') || rawName.contains('(ارتفاع)')) {
      return rawName
          .replaceAll('(عرض)', '(طول + عرض)')
          .replaceAll('(ارتفاع)', '(طول + عرض)');
    }
    return rawName;
  }

  /// محرك حساب الطلبية الشامل (مطابق لحساب الطلبية في الورشة الذكية - المشروع المماثل):
  /// 1. يدمج طول وعرض الدرفة (أو الحلق أو الباكتة) في بند واحد مشترك بدلاً من تفكيكهما في بنود منفصلة.
  /// 2. يطبق قاعدة (شباك جرار + ثابت علوي): يصنع الجرار بدون بار + الثابت العلوي بدون بار + يربط بينهما بقطاع "إتش" (H-profile) + يلف حولهما بار منفصل حوالين داير.
  /// 3. يطبق قواعد درف الباندا (درف أمامية للزجاج + درف خلفية للسلك) وقواعد الأبواب (كعب الباب وعارضة الوسط).
  /// 4. لا يقوم بتضليع الدوران في أعواد القص العادية، بل يخرجه في تقرير الدورانات المنفصل للدرفلة.
  List<AggregatedProfileOrder> calculateAggregatedProfilesOrder(
      List<ClientWindowItem> items) {
    final double stockLen = pricingSettings.defaultStockBarLengthCm;
    final double kerfMm = pricingSettings.defaultSawKerfMm;

    final Map<String, Map<String, dynamic>> grouped = {};

    void addPartCut({
      required SectorProfile sector,
      required String rawPartName,
      required String role,
      required String? svgPath,
      required double cutLengthCm,
      required int totalCount,
      String? dimTag, // عرض | ارتفاع | طول
    }) {
      if (cutLengthCm <= 0 || totalCount <= 0) return;
      final String unifiedName = _unifyProfilePartName(rawPartName);
      final String resolvedSvg = svgPath ?? sector.primaryProfileSvg ?? '';
      final String key = '${sector.id}__${unifiedName}__$resolvedSvg';

      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'sectorName': sector.name,
          'partName': unifiedName,
          'role': role,
          'svgAssetPath': resolvedSvg,
          'lengthCounts': <double, int>{},
          'dimBreakdowns': <String, int>{},
          'allPieces': <double>[],
        };
      }
      final Map<double, int> lc =
          grouped[key]!['lengthCounts'] as Map<double, int>;
      final Map<String, int> db =
          grouped[key]!['dimBreakdowns'] as Map<String, int>;
      final List<double> allP = grouped[key]!['allPieces'] as List<double>;
      final double roundedLen = double.parse(cutLengthCm.toStringAsFixed(1));
      lc[roundedLen] = (lc[roundedLen] ?? 0) + totalCount;

      final String tagPrefix = dimTag ??
          (rawPartName.contains('عرض')
              ? 'عرض'
              : (rawPartName.contains('ارتفاع') ? 'طول/ارتفاع' : 'طول'));
      final String bdKey = '$tagPrefix: ${roundedLen.toStringAsFixed(1)} سم';
      db[bdKey] = (db[bdKey] ?? 0) + totalCount;

      for (int k = 0; k < totalCount; k++) {
        allP.add(roundedLen);
      }
    }

    for (final item in items) {
      final sector = getSectorById(item.sectorId);
      if (sector == null) continue;

      final bool isWithoutBarUser = item.barType.contains('بدون');
      final bool isDoor = item.unitType.contains('باب');
      final bool isPandaActive = item.hasPanda &&
          (item.openType.contains('مفصلي') || item.openType.contains('قلاب'));
      final bool isSlidingPlusTopFixedH =
          item.usesSlidingWithTopFixedHConnector;

      // في حالة شباك جرار وفوقه ثابت علوي: يتم تصنيع الشباك الجرار والثابت كقطعتين منفصلتين بدون بار مدمج أولاً!
      final bool forceFrameWithoutBar =
          isWithoutBarUser || isSlidingPlusTopFixedH;

      final bool hasFixedAny = item.hasTopFixed ||
          item.hasBottomFixed ||
          item.hasRightFixed ||
          item.hasLeftFixed;

      for (final part in sector.parts) {
        if (part.condition == 'with_bar' && forceFrameWithoutBar) continue;
        if (part.condition == 'without_bar' && !forceFrameWithoutBar) continue;
        if (part.condition == 'window_only' && isDoor) continue;
        if (part.condition == 'door_only' && !isDoor) continue;
        if (part.condition == 'fly_screen' && !item.hasFlyScreen) continue;
        if (part.condition == 'panda_only' && !isPandaActive) continue;
        if (part.condition == 'fixed_only' && !hasFixedAny) continue;
        if (part.condition == 'single_glass' && item.isDoubleGlass) continue;
        if (part.condition == 'double_glass' && !item.isDoubleGlass) continue;
        if (part.condition == 'track_3' && item.trackCount < 3) continue;

        if (item.openType == 'ثابت' &&
            (part.role == 'ضلفة' ||
                part.role == 'درفة' ||
                part.role == 'سكينة' ||
                part.role == 'منخل' ||
                part.role == 'باندا')) {
          continue;
        }

        // في حالة شباك جرار + ثابت علوي (إتش): الحلق الجرار يأخذ مقاس الجزء المتحرك فقط (لأن الثابت العلوي له حلق مستقل فوق الإتش)
        double frameBaseW = item.widthCm;
        double frameBaseH = item.heightCm;
        if (isSlidingPlusTopFixedH && part.role == 'حلق') {
          frameBaseW = item.netOperableWidthCm;
          frameBaseH = item.netOperableHeightCm;
        }

        final double cutLen = part.calculatePieceLength(
          frameBaseW,
          frameBaseH,
          item.sashCount,
          netWidthCm: item.netOperableWidthCm,
          netHeightCm: item.netOperableHeightCm,
        );
        if (cutLen <= 0) continue;

        // إذا كان الباب بدون كعب سفلي مستمر، الحلق الرأسي يأخذ 2 قطعة والعرضي 1 قطعة علوية
        int count = part.calculateTotalCount(item.quantity, item.sashCount);
        if (isDoor &&
            part.role == 'حلق' &&
            part.dimensionBasis == 'width' &&
            item.hasDoorKickplate) {
          count = 1 * item.quantity; // عارضة حلق علوية فقط والأسفل معبر/كعب
        }

        addPartCut(
          sector: sector,
          rawPartName: part.name,
          role: part.role,
          svgPath: part.svgAssetPath,
          cutLengthCm: cutLen,
          totalCount: count,
        );
      }

      // ==================== حالة خاصة (5): شباك جرار + ثابت علوي + قطاع "إتش" + بار منفصل حوالين داير ====================
      if (isSlidingPlusTopFixedH) {
        final String? withoutBarSvg = sector.parts
                .where((p) => p.condition == 'without_bar')
                .map((p) => p.svgAssetPath)
                .firstOrNull ??
            sector.primaryProfileSvg;
        final String? hProfileSvg =
            sector.hConnectorSvg ?? sector.fixedTransomSvg ?? sector.primaryProfileSvg;
        final String? architraveSvg =
            sector.architraveBarSvg ?? sector.primaryProfileSvg;

        // 1. حلق الثابت العلوي المنفصل (بدون بار مدمج)
        addPartCut(
          sector: sector,
          rawPartName: 'حلق ثابت علوي منفصل بدون بار (عرض)',
          role: 'حلق',
          svgPath: withoutBarSvg,
          cutLengthCm: item.widthCm,
          totalCount: 2 * item.quantity,
          dimTag: 'عرض الثابت',
        );
        addPartCut(
          sector: sector,
          rawPartName: 'حلق ثابت علوي منفصل بدون بار (ارتفاع)',
          role: 'حلق',
          svgPath: withoutBarSvg,
          cutLengthCm: item.topFixedHeightCm,
          totalCount: 2 * item.quantity,
          dimTag: 'ارتفاع الثابت',
        );

        // 2. قطاع "إتش" (H-profile / إتش وإتش) المشترك الفاصل بين الشباك الجرار والثابت العلوي
        addPartCut(
          sector: sector,
          rawPartName: 'قطاع إتش (H-Profile) فاصل بين الجرار والثابت',
          role: 'إتش',
          svgPath: hProfileSvg,
          cutLengthCm: item.widthCm,
          totalCount: 1 * item.quantity,
          dimTag: 'طول الإتش الفاصل',
        );

        // 3. بار منفصل يلتف حوالين داير حول الشباك والثابت معاً (إذا كان الشباك مطلوباً ببار)
        if (!isWithoutBarUser) {
          addPartCut(
            sector: sector,
            rawPartName: 'بار منفصل خارجي حوالين داير (عرض)',
            role: 'بار',
            svgPath: architraveSvg,
            cutLengthCm: item.widthCm + 8.0,
            totalCount: 2 * item.quantity,
            dimTag: 'عرض البار المحيط',
          );
          addPartCut(
            sector: sector,
            rawPartName: 'بار منفصل خارجي حوالين داير (ارتفاع)',
            role: 'بار',
            svgPath: architraveSvg,
            cutLengthCm: item.heightCm + 8.0,
            totalCount: 2 * item.quantity,
            dimTag: 'ارتفاع البار المحيط',
          );
        }
      }

      // ==================== قسم الأبواب: كعب الباب السفلي وعارضة الوسط ====================
      if (isDoor) {
        final double doorLeafNetW = sector.calculateGlassWidthCm(
          item.netOperableWidthCm,
          item.sashCount,
          isDoor: true,
        );
        if (item.hasDoorKickplate) {
          addPartCut(
            sector: sector,
            rawPartName: 'كعب باب سفلي عريض (سوكلي)',
            role: 'كعب',
            svgPath: sector.doorKickplateSvg ?? sector.fixedTransomSvg,
            cutLengthCm: math.max(25.0, doorLeafNetW),
            totalCount: item.sashCount * item.quantity,
            dimTag: 'عرض الكعب',
          );
        }
        if (item.hasDoorMiddleMullion) {
          addPartCut(
            sector: sector,
            rawPartName: 'سؤاس / عارضة وسط الباب',
            role: 'سؤاس',
            svgPath: sector.fixedTransomSvg ?? sector.primaryProfileSvg,
            cutLengthCm: math.max(25.0, doorLeafNetW),
            totalCount: item.sashCount * item.quantity,
            dimTag: 'عرض السؤاس',
          );
        }
      }

      // ==================== قواطيع وسؤاسات الثوابت وباكتات الزجاج للثوابت ====================
      if (hasFixedAny || (item.openType == 'ثابت' && item.sashCount > 1)) {
        final String? fixedTransomSvg =
            sector.fixedTransomSvg ?? sector.primaryProfileSvg;
        final String? fixedBeadSvg = item.isDoubleGlass
            ? (sector.fixedBeadDoubleSvg ??
                sector.fixedBeadSingleSvg ??
                sector.primaryProfileSvg)
            : (sector.fixedBeadSingleSvg ??
                sector.fixedBeadDoubleSvg ??
                sector.primaryProfileSvg);
        final double tDeduct = sector.transomDeductCm;

        if (item.hasTopFixed && item.topFixedHeightCm > 0) {
          // إذا لم يكن جرار+ثابت بقطاع إتش (أي كان مفصلي مع ثابت علوي)، يضاف سؤاس أفقي فاصل
          if (!isSlidingPlusTopFixedH) {
            addPartCut(
              sector: sector,
              rawPartName: 'سؤاس / قاطع ثابت (طول + عرض)',
              role: 'سؤاس',
              svgPath: fixedTransomSvg,
              cutLengthCm: math.max(10.0, item.widthCm - tDeduct),
              totalCount: 1 * item.quantity,
              dimTag: 'قاطع أفقي',
            );
          }
          // قواطيع تقسيم الثابت العلوي الرأسية (إن كان مقسوماً لـ 2 أو 3 أو 4 أجزاء)
          if (item.topFixedSplits > 1) {
            addPartCut(
              sector: sector,
              rawPartName: 'سؤاس تقسيم الثابت (طول + عرض)',
              role: 'سؤاس',
              svgPath: fixedTransomSvg,
              cutLengthCm: math.max(10.0, item.topFixedHeightCm - tDeduct),
              totalCount: (item.topFixedSplits - 1) * item.quantity,
              dimTag: 'قواطيع الثابت العلوي',
            );
          }
          // باكتة زجاج الثابت العلوي (تدمج الطول والعرض في بند باكتة الثابت)
          final double subW = sector.calculateFixedPaneGlassWidth(
              item.widthCm, item.topFixedSplits);
          final double subH = sector.calculateFixedPaneGlassHeight(
              item.topFixedHeightCm, 1);
          addPartCut(
            sector: sector,
            rawPartName: 'باكتة زجاج الثابت (عرض)',
            role: 'باكتة',
            svgPath: fixedBeadSvg,
            cutLengthCm: subW,
            totalCount: 2 * math.max<int>(1, item.topFixedSplits) * item.quantity,
            dimTag: 'عرض باكتة الثابت',
          );
          addPartCut(
            sector: sector,
            rawPartName: 'باكتة زجاج الثابت (ارتفاع)',
            role: 'باكتة',
            svgPath: fixedBeadSvg,
            cutLengthCm: subH,
            totalCount: 2 * math.max<int>(1, item.topFixedSplits) * item.quantity,
            dimTag: 'ارتفاع باكتة الثابت',
          );
        }

        if (item.hasBottomFixed && item.bottomFixedHeightCm > 0) {
          addPartCut(
            sector: sector,
            rawPartName: 'سؤاس / قاطع ثابت (طول + عرض)',
            role: 'سؤاس',
            svgPath: fixedTransomSvg,
            cutLengthCm: math.max(10.0, item.widthCm - tDeduct),
            totalCount: 1 * item.quantity,
            dimTag: 'قاطع سفلي',
          );
          if (item.bottomFixedSplits > 1) {
            addPartCut(
              sector: sector,
              rawPartName: 'سؤاس تقسيم الثابت (طول + عرض)',
              role: 'سؤاس',
              svgPath: fixedTransomSvg,
              cutLengthCm: math.max(10.0, item.bottomFixedHeightCm - tDeduct),
              totalCount: (item.bottomFixedSplits - 1) * item.quantity,
              dimTag: 'قواطيع الثابت السفلي',
            );
          }
          final double subW = sector.calculateFixedPaneGlassWidth(
              item.widthCm, item.bottomFixedSplits);
          final double subH = sector.calculateFixedPaneGlassHeight(
              item.bottomFixedHeightCm, 1);
          addPartCut(
            sector: sector,
            rawPartName: 'باكتة زجاج الثابت (عرض)',
            role: 'باكتة',
            svgPath: fixedBeadSvg,
            cutLengthCm: subW,
            totalCount: 2 * math.max<int>(1, item.bottomFixedSplits) * item.quantity,
            dimTag: 'عرض باكتة الثابت',
          );
          addPartCut(
            sector: sector,
            rawPartName: 'باكتة زجاج الثابت (ارتفاع)',
            role: 'باكتة',
            svgPath: fixedBeadSvg,
            cutLengthCm: subH,
            totalCount: 2 * math.max<int>(1, item.bottomFixedSplits) * item.quantity,
            dimTag: 'ارتفاع باكتة الثابت',
          );
        }

        if (item.hasRightFixed && item.rightFixedWidthCm > 0) {
          addPartCut(
            sector: sector,
            rawPartName: 'سؤاس / قاطع ثابت (طول + عرض)',
            role: 'سؤاس',
            svgPath: fixedTransomSvg,
            cutLengthCm: math.max(10.0, item.netOperableHeightCm - tDeduct),
            totalCount: 1 * item.quantity,
            dimTag: 'قاطع رأسي يمين',
          );
          if (item.rightFixedSplits > 1) {
            addPartCut(
              sector: sector,
              rawPartName: 'سؤاس تقسيم الثابت (طول + عرض)',
              role: 'سؤاس',
              svgPath: fixedTransomSvg,
              cutLengthCm: math.max(10.0, item.rightFixedWidthCm - tDeduct),
              totalCount: (item.rightFixedSplits - 1) * item.quantity,
              dimTag: 'قواطيع الثابت اليمين',
            );
          }
        }

        if (item.hasLeftFixed && item.leftFixedWidthCm > 0) {
          addPartCut(
            sector: sector,
            rawPartName: 'سؤاس / قاطع ثابت (طول + عرض)',
            role: 'سؤاس',
            svgPath: fixedTransomSvg,
            cutLengthCm: math.max(10.0, item.netOperableHeightCm - tDeduct),
            totalCount: 1 * item.quantity,
            dimTag: 'قاطع رأسي شمال',
          );
          if (item.leftFixedSplits > 1) {
            addPartCut(
              sector: sector,
              rawPartName: 'سؤاس تقسيم الثابت (طول + عرض)',
              role: 'سؤاس',
              svgPath: fixedTransomSvg,
              cutLengthCm: math.max(10.0, item.leftFixedWidthCm - tDeduct),
              totalCount: (item.leftFixedSplits - 1) * item.quantity,
              dimTag: 'قواطيع الثابت الشمال',
            );
          }
        }
      }
    }

    final List<AggregatedProfileOrder> result = [];
    grouped.forEach((_, data) {
      final List<double> allPieces = List<double>.from(data['allPieces']);
      if (allPieces.isEmpty) return;
      final plans = optimize1DBars(
        requiredPiecesCm: allPieces,
        stockLengthCm: stockLen,
        sawKerfMm: kerfMm,
      );
      final Map<String, int> db =
          Map<String, int>.from(data['dimBreakdowns'] ?? {});
      final List<String> breakdownLabels =
          db.entries.map((e) => '${e.key} × ${e.value} قطعة').toList();

      result.add(AggregatedProfileOrder(
        sectorName: data['sectorName'],
        partName: data['partName'],
        role: data['role'],
        svgAssetPath: data['svgAssetPath'],
        lengthCounts: Map<double, int>.from(data['lengthCounts']),
        dimensionBreakdownLabels: breakdownLabels,
        allPiecesCm: allPieces,
        barPlans: plans,
      ));
    });

    return result;
  }

  /// استخراج بيان مقاسات الدورانات (الأقواس) المطلوب إبلاغ ورشة الدرفلة بها فقط دون تضليعها في أعواد القص
  List<ArchReportItem> buildArchReportList(List<ClientWindowItem> items) {
    final List<ArchReportItem> list = [];
    for (final item in items) {
      if (!item.hasArch) continue;
      final sec = getSectorById(item.sectorId);
      final double chordW =
          item.archWidthCm > 0 ? item.archWidthCm : item.widthCm;
      final double riseH = item.archHeightCm > 0 ? item.archHeightCm : 25.0;
      final double r = item.archRadiusCm;
      final double netArc = item.archNetArcLengthCm;
      list.add(
        ArchReportItem(
          windowLabel: item.label,
          sectorName: sec?.name ?? item.sectorName,
          sectorColor: item.sectorColor,
          quantity: item.quantity,
          chordWidthCm: chordW,
          archRiseHeightCm: riseH,
          radiusCm: double.parse(r.toStringAsFixed(1)),
          netArcLengthCm: double.parse(netArc.toStringAsFixed(1)),
          rollingBarLengthCm: double.parse((netArc + 20.0).toStringAsFixed(1)),
          archPricePerWindow: item.archPriceEgp,
        ),
      );
    }
    return list;
  }

  /// حساب كافة إكسسوارات الشبابيك والأبواب في الطلبية (مقابض، عجل، عضم، ميجا، تراك، رينو 90 درجة، مانع ارتجاج، فرش، كاوتش، سلك...)
  List<CalculatedAccessoryOrderItem> calculateAccessoriesOrder(
      List<ClientWindowItem> items) {
    int totalRenoAngles = 0; // زوايا رينو 90 درجة لتجميع الحلق والضلف
    int totalCornerJoints = 0; // عضم تجميع وزوايا سلك
    int totalSlidingRollersPairs = 0; // أطقم عجل جرار دبل رمان بلي
    int totalFlyScreenRollersSets = 0; // أطقم عجل سلك
    int totalAntiRattlePieces = 0; // مانع ارتجاج ودليل علوي للجرار
    int totalMegaLocks = 0; // صكاك / مقبض ميجا (Mega)
    int totalTrackMechanisms = 0; // ذراع تراك / ماكينة تراك (Track)
    int totalHingedHandles = 0; // مقبض مفصلي / قلاب
    int totalPandaSets = 0; // طقم مقبض ومفصلات باندا
    int totalDoorLocks = 0; // كالون ومقبض باب بمفتاح
    int totalWindowHingesPairs = 0; // أطقم مفصلات شباك مفصلي
    int totalDoorHingesSets = 0; // أطقم مفصلات باب ثقيلة (3 درف للمفصلة)
    int totalStoppersAndDrainCaps = 0; // صدادات وكابات تصريف مياه
    double totalRubberGasketMeters = 0.0; // كاوتش EPDM بالمتر الطولي
    double totalBrushSealMeters = 0.0; // فرش عازل للأتربة بالمتر الطولي
    double totalFlyScreenAreaM2 = 0.0; // سلك فايبر / ألومنيوم بالمتر المربع
    double totalDoubleSpacerMeters = 0.0; // سبيسر زجاج دبل بالمتر الطولي

    for (final item in items) {
      final int q = item.quantity > 0 ? item.quantity : 1;
      final int sashes = item.sashCount > 0 ? item.sashCount : 1;
      final bool isSliding = item.openType == 'جرار';
      final bool isHinged =
          item.openType == 'مفصلي' || item.openType == 'قلاب';
      final bool isDoor = item.unitType == 'باب';
      final bool isPanda = item.hasPanda && isHinged;

      // 1. زوايا رينو (90 درجة): 4 زوايا للحلق + 4 زوايا لكل ضلفة زجاج + 4 زوايا لكل ضلفة باندا + 4 للثابت المنفصل
      int renoPerWin = 4 + (sashes * 4);
      if (isPanda) renoPerWin += (sashes * 4);
      if (item.usesSlidingWithTopFixedHConnector) renoPerWin += 4;
      totalRenoAngles += renoPerWin * q;

      // 2. عضم تجميع وزوايا سلك (عضم 90)
      int adhmPerWin = 4;
      if (item.hasFlyScreen) adhmPerWin += 4;
      if (isPanda) adhmPerWin += (sashes * 4);
      totalCornerJoints += adhmPerWin * q;

      // 3. إكسسوارات الجرار (عجل، مانع ارتجاج، ميجا، تراك، فرش، صدادات)
      if (isSliding) {
        totalSlidingRollersPairs += sashes * q; // طقم عجل لكل ضلفة
        totalAntiRattlePieces += (sashes * 2) * q; // 2 مانع ارتجاج لكل ضلفة جرار
        totalMegaLocks += (sashes >= 2 ? 2 : 1) * q; // صكاك ميجا أوتوماتيك للجرار
        totalTrackMechanisms += item.trackCount * q; // مجرى / تراك سكة الجرار
        totalStoppersAndDrainCaps += 4 * q; // صدادات وكابات تصريف مياه
        if (item.hasFlyScreen) {
          totalFlyScreenRollersSets += 1 * q;
        }
        // الفرش للجرار: محيط الضلف × 2
        final double sashPerimM =
            2.0 * ((item.netOperableWidthCm / sashes + item.netOperableHeightCm) / 100.0);
        totalBrushSealMeters += (sashPerimM * sashes * 2.0) * q;
      }

      // 4. إكسسوارات المفصلي والقلاب والباندا والأبواب
      if (isHinged) {
        if (isDoor) {
          totalDoorLocks += 1 * q;
          totalDoorHingesSets += sashes * q;
        } else if (isPanda) {
          totalPandaSets += sashes * q;
          totalWindowHingesPairs += (sashes * 2) * q; // مفصلات للدرف الأمامية والخلفية
          totalTrackMechanisms += sashes * q; // ذراع تراك / سقاطة مفصلي
        } else {
          totalHingedHandles += sashes * q;
          totalWindowHingesPairs += sashes * q;
          totalTrackMechanisms += sashes * q; // ذراع تراك / ماكينة قلاب أو مفصلي
        }
      }

      // 5. حساب الكاوتش العازل (EPDM) حول الزجاج والضلف
      final double winPerimM =
          2.0 * ((item.widthCm + item.heightCm) / 100.0);
      final double glassPerimM =
          winPerimM * (item.isDoubleGlass ? 2.4 : 1.6);
      totalRubberGasketMeters += glassPerimM * q;

      // 6. حساب مساحة السلك (للجرار بالسلك أو لنظام الباندا)
      if (item.hasFlyScreen || isPanda) {
        final double meshArea =
            (item.netOperableWidthCm / 100.0) * (item.netOperableHeightCm / 100.0);
        totalFlyScreenAreaM2 +=
            (isSliding ? (meshArea * 0.5) : meshArea) * q;
      }

      // 7. حساب أمتار السبيسر في حالة الزجاج الدبل
      if (item.hasGlass && item.isDoubleGlass) {
        totalDoubleSpacerMeters += (winPerimM * 1.35) * q;
      }
    }

    double priceOf(String id, double fallback) {
      for (final a in accessories) {
        if (a.id == id) return a.price;
      }
      return fallback;
    }

    final List<CalculatedAccessoryOrderItem> list = [];

    if (totalRenoAngles > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_reno_90',
        name: 'رينو — زوايا تجميع القطاعات بزاوية 90 درجة (Reno)',
        category: 'تجميع وزوايا رينو وعضم',
        unit: 'قطعة',
        totalQuantity: totalRenoAngles.toDouble(),
        unitPrice: priceOf('acc_reno_90', 25.0),
        notes: 'يمسك القطعتين في بعض بزاوية 90 درجة للحلق والضلف',
      ));
    }
    if (totalCornerJoints > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_adhm_corner',
        name: 'عضم تجميع وزوايا سلك وباكتات (عضم 90)',
        category: 'تجميع وزوايا رينو وعضم',
        unit: 'قطعة',
        totalQuantity: totalCornerJoints.toDouble(),
        unitPrice: priceOf('acc_adhm_corner', 10.0),
        notes: 'عضم تجميع الزوايا وضلف السلك',
      ));
    }
    if (totalMegaLocks > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_mega_lock',
        name: 'ميجا — صكاك ومقبض ميجا أوتوماتيك (Mega)',
        category: 'مقابض وميجا وتراك',
        unit: 'قطعة',
        totalQuantity: totalMegaLocks.toDouble(),
        unitPrice: priceOf('acc_handle_sliding', 180.0),
        notes: 'صكاك ومقبض ميجا للضلف الجرار',
      ));
    }
    if (totalTrackMechanisms > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_track_mech',
        name: 'تراك — إكسسوار تراك ومجرى حركة (Track)',
        category: 'مقابض وميجا وتراك',
        unit: 'طقم',
        totalQuantity: totalTrackMechanisms.toDouble(),
        unitPrice: priceOf('acc_track_mech', 95.0),
        notes: 'تراك حركة السكة أو ذراع تراك المفصلي/القلاب',
      ));
    }
    if (totalAntiRattlePieces > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_anti_rattle',
        name: 'مانع ارتجاج ودليل علوي للضلف الجرار',
        category: 'حركة وعجل ومانع ارتجاج',
        unit: 'قطعة',
        totalQuantity: totalAntiRattlePieces.toDouble(),
        unitPrice: priceOf('acc_anti_rattle', 15.0),
        notes: 'لمنع ارتجاج الضلف وإحكام حركتها داخل الحلق',
      ));
    }
    if (totalSlidingRollersPairs > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_rollers_double',
        name: 'طقم عجل جرار دبل روحين بالرمان بلي',
        category: 'حركة وعجل ومانع ارتجاج',
        unit: 'طقم',
        totalQuantity: totalSlidingRollersPairs.toDouble(),
        unitPrice: priceOf('acc_rollers_double', 160.0),
        notes: 'طقم عجل ثقيل لكل ضلفة جرار',
      ));
    }
    if (totalFlyScreenRollersSets > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_screen_rollers',
        name: 'طقم عجل ضلفة سلك جرار',
        category: 'حركة وعجل ومانع ارتجاج',
        unit: 'طقم',
        totalQuantity: totalFlyScreenRollersSets.toDouble(),
        unitPrice: priceOf('acc_screen_rollers', 45.0),
        notes: 'عجل خاص بضلفة السلك',
      ));
    }
    if (totalPandaSets > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_handle_panda',
        name: 'طقم مقبض وسقاطة ومفصلات نظام باندا (Panda)',
        category: 'مقابض وميجا وتراك',
        unit: 'طقم',
        totalQuantity: totalPandaSets.toDouble(),
        unitPrice: priceOf('acc_handle_panda', 260.0),
        notes: 'لربط وتشغيل الدرف الأمامية الزجاج والخلفية السلك للباندا',
      ));
    }
    if (totalHingedHandles > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_handle_hinged',
        name: 'مقبض مفصلي / قلاب تركي بالماكينة',
        category: 'مقابض وميجا وتراك',
        unit: 'طقم',
        totalQuantity: totalHingedHandles.toDouble(),
        unitPrice: priceOf('acc_handle_hinged', 220.0),
        notes: 'مقبض شباك مفصلي بالماكينة واللسان',
      ));
    }
    if (totalDoorLocks > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_door_lock',
        name: 'كالون ومقبض باب ألوميتال سلندر بمفتاح',
        category: 'مقابض وميجا وتراك',
        unit: 'طقم',
        totalQuantity: totalDoorLocks.toDouble(),
        unitPrice: priceOf('acc_door_lock', 450.0),
        notes: 'كالون باب كامل بالمقابض والسلندر',
      ));
    }
    if (totalWindowHingesPairs > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_hinges_pair',
        name: 'طقم مفصلات شباك مفصلي / باندا إيطالي ثقيل',
        category: 'حركة وعجل ومانع ارتجاج',
        unit: 'طقم',
        totalQuantity: totalWindowHingesPairs.toDouble(),
        unitPrice: priceOf('acc_hinges_pair', 120.0),
        notes: 'مفصلات الدرف المفصلية والباندا',
      ));
    }
    if (totalDoorHingesSets > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_door_hinges',
        name: 'طقم مفصلات باب ثقيلة ثلاثية (3 مفصلات للدرفة)',
        category: 'حركة وعجل ومانع ارتجاج',
        unit: 'طقم',
        totalQuantity: totalDoorHingesSets.toDouble(),
        unitPrice: priceOf('acc_door_hinges', 280.0),
        notes: 'مفصلات خدمة شاقة للأبواب',
      ));
    }
    if (totalStoppersAndDrainCaps > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_stoppers_caps',
        name: 'صدادات جرار وكابات تصريف مياه ومقابض سلك',
        category: 'تجميع وزوايا رينو وعضم',
        unit: 'طقم',
        totalQuantity: totalStoppersAndDrainCaps.toDouble(),
        unitPrice: priceOf('acc_stoppers_caps', 20.0),
        notes: 'صدادات سكة وكابات مطر',
      ));
    }
    if (totalRubberGasketMeters > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_rubber_gasket',
        name: 'كاوتش EPDM عازل للزجاج والضلف والحلق',
        category: 'كاوتش وفرش وسلك',
        unit: 'متر طولي',
        totalQuantity: double.parse(totalRubberGasketMeters.toStringAsFixed(1)),
        unitPrice: priceOf('acc_rubber_gasket', 15.0),
        notes: 'كاوتش زجاج وكاوتش بار ومفصلي',
      ));
    }
    if (totalBrushSealMeters > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_brush_seal',
        name: 'فرش عازل للأتربة والهواء (جرار وسلك)',
        category: 'كاوتش وفرش وسلك',
        unit: 'متر طولي',
        totalQuantity: double.parse(totalBrushSealMeters.toStringAsFixed(1)),
        unitPrice: priceOf('acc_brush_seal', 12.0),
        notes: 'فرش مجرى الضلف الجرار والسلك',
      ));
    }
    if (totalFlyScreenAreaM2 > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_fly_mesh',
        name: 'سلك فايبر / ألومنيوم مانع للحشرات',
        category: 'كاوتش وفرش وسلك',
        unit: 'متر مربع',
        totalQuantity: double.parse(totalFlyScreenAreaM2.toStringAsFixed(2)),
        unitPrice: priceOf('acc_fly_mesh', 250.0),
        notes: 'شاملاً كاوتش السلك للضلف والباندا',
      ));
    }
    if (totalDoubleSpacerMeters > 0) {
      list.add(CalculatedAccessoryOrderItem(
        id: 'acc_double_spacer',
        name: 'سبيسر ألومنيوم للزجاج الدبل + بوتيل ومادة عزل',
        category: 'كاوتش وفرش وسلك',
        unit: 'متر طولي',
        totalQuantity: double.parse(totalDoubleSpacerMeters.toStringAsFixed(1)),
        unitPrice: pricingSettings.doubleSpacerPricePerMeter,
        notes: 'سبيسر بين طبقتي الزجاج الدبل',
      ));
    }

    return list;
  }

  /// السجل النموذجي المطابق تماماً لملف (أ. احمد ابو اليزيد.pdf)
  ClientRecord _sampleAhmedAboElYazeedRecord() {
    return ClientRecord(
      id: 'client_ahmed_abo_elyazeed',
      clientName: 'أ. احمد ابو اليزيد',
      clientPhone: '01000000000',
      clientAddress: 'ابراج الروضه شارع ناصر',
      createdAt: '2026-11-04',
      discountAmount: 0.0,
      depositAmount: 0.0,
      archCost: 0.0,
      notes: 'مقايسة شبابيك UPVC و P.S مطابقة للنموذج المعتمد',
      items: [
        ClientWindowItem(
          id: 'w1',
          label: 'W1',
          unitType: 'شباك',
          openType: 'جرار',
          sashCount: 2,
          sectorId: 'sec_upvc_eg_large_sliding',
          sectorName: 'UPVC كبير',
          customPdfDescription: 'جرار ٢ ضلفة\nUPVC كبير',
          sectorColor: 'بيج',
          widthCm: 267,
          heightCm: 213,
          quantity: 1,
          sectorPricePerM2: 5500,
          isCombinedMeterPrice: true,
          hasGlass: true,
          isDoubleGlass: true,
          glass1Name: 'دبل\nعاكس\nأخضر\nعلى شفاف',
        ),
        ClientWindowItem(
          id: 'w2',
          label: 'W2',
          unitType: 'شباك',
          openType: 'جرار',
          sashCount: 2,
          sectorId: 'sec_upvc_eg_large_sliding',
          sectorName: 'UPVC كبير',
          customPdfDescription: 'جرار ٢ ضلفة\nUPVC كبير',
          sectorColor: 'بيج',
          widthCm: 231,
          heightCm: 214,
          quantity: 1,
          sectorPricePerM2: 5500,
          isCombinedMeterPrice: true,
          hasGlass: true,
          isDoubleGlass: true,
          glass1Name: 'دبل\nعاكس\nأخضر\nعلى شفاف',
        ),
        ClientWindowItem(
          id: 'w3',
          label: 'W3',
          unitType: 'شباك',
          openType: 'جرار',
          sashCount: 2,
          sectorId: 'sec_upvc_eg_large_sliding',
          sectorName: 'UPVC كبير',
          customPdfDescription: 'جرار ٢ ضلفة\nUPVC كبير',
          sectorColor: 'بيج',
          widthCm: 138,
          heightCm: 92,
          quantity: 1,
          sectorPricePerM2: 5500,
          isCombinedMeterPrice: true,
          hasGlass: true,
          isDoubleGlass: true,
          glass1Name: 'دبل\nعاكس\nأخضر\nعلى شفاف',
        ),
        ClientWindowItem(
          id: 'w4',
          label: 'W4',
          unitType: 'شباك',
          openType: 'جرار',
          sashCount: 2,
          sectorId: 'sec_upvc_eg_large_sliding',
          sectorName: 'UPVC كبير',
          customPdfDescription: 'جرار ٢ ضلفة\nUPVC كبير',
          sectorColor: 'بيج',
          widthCm: 119,
          heightCm: 99,
          quantity: 1,
          sectorPricePerM2: 4500,
          isCombinedMeterPrice: true,
          hasGlass: true,
          isDoubleGlass: false,
          glass1Name: 'سنجل\nمصنفر',
        ),
        ClientWindowItem(
          id: 'w5',
          label: 'W5',
          unitType: 'شباك',
          openType: 'جرار',
          sashCount: 2,
          sectorId: 'sec_ps_6600',
          sectorName: 'صغير P.S',
          customPdfDescription: 'جرار ٢ ضلفة\nصغير P.S',
          sectorColor: 'أسود',
          widthCm: 81,
          heightCm: 69,
          quantity: 1,
          sectorPricePerM2: 5500,
          isCombinedMeterPrice: true,
          hasGlass: true,
          isDoubleGlass: false,
          glass1Name: 'سنجل\nمصنفر',
        ),
        ClientWindowItem(
          id: 'w6',
          label: 'W6',
          unitType: 'شباك',
          openType: 'قلاب',
          sashCount: 1,
          sectorId: 'sec_upvc_eg_hinged',
          sectorName: 'UPVC كبير',
          customPdfDescription: 'قلاب ١ ضلفة\nUPVC كبير',
          sectorColor: 'بيج',
          widthCm: 45,
          heightCm: 56,
          quantity: 1,
          sectorPricePerM2: 4500,
          isCombinedMeterPrice: true,
          hasGlass: true,
          isDoubleGlass: false,
          glass1Name: 'سنجل\nمصنفر',
        ),
      ],
    );
  }

  /// جميع القطاعات القياسية بأشكال المقاطع (SVG) المضبوطة لكل جزء ومعادلات الزجاج والتخصيم الدقيقة
  List<SectorProfile> _allStandardSectors() {
    return [
      // ==================== 1. قطاعات السلام (PS) ====================
      _buildSlidingSectorExact(
        id: 'sec_ps_9600',
        name: 'بي إس 9600 جرار كبير (PS 9600)',
        shortPdfName: 'كبير P.S',
        group: 'قطاعات السلام (PS)',
        logo: 'assets/images/windows/systems/s000.png',
        svgFolder: 'assets/images/svg/profiles/ps/9600',
        svgFrameWithBar: 'assets/images/svg/profiles/ps/9600/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/ps/9600/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/ps/9600/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/ps/9600/009.svg',
        svgSashDoor: 'assets/images/svg/profiles/ps/9600/010.svg',
        svgFlyScreen: 'assets/images/svg/profiles/ps/9600/004.svg',
        svgInterlock: 'assets/images/svg/profiles/ps/9600/005.svg',
        svgTransom: 'assets/images/svg/profiles/ps/all/003.svg',
        svgBeadSingle: 'assets/images/svg/profiles/ps/5600/008.svg',
        svgBeadDouble: 'assets/images/svg/profiles/ps/5600/009.svg',
        catalogUrl: 'https://drive.google.com/drive/search?q=PS+9600+profile',
        price: 4200,
        gwDeduct: 10.6,
        ghDeduct: 10.6,
        fixedGlassDeduct: 6.8,
        transomDeduct: 5.8,
        sashWOffset2: -0.5,
        sashWOffset3: 0.7,
        sashWOffset4: -0.25,
        sashHOffset: -6.5,
      ),
      _buildSlidingSectorExact(
        id: 'sec_ps_6600',
        name: 'بي إس 6600 جرار صغير (PS 6600)',
        shortPdfName: 'صغير P.S',
        group: 'قطاعات السلام (PS)',
        logo: 'assets/images/windows/systems/s000.png',
        svgFolder: 'assets/images/svg/profiles/ps/6600',
        svgFrameWithBar: 'assets/images/svg/profiles/ps/6600/008.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/ps/6600/009.svg',
        svgFrame3Track: 'assets/images/svg/profiles/ps/6600/004.svg',
        svgSashWindow: 'assets/images/svg/profiles/ps/6600/001.svg',
        svgSashDoor: 'assets/images/svg/profiles/ps/6600/007.svg',
        svgFlyScreen: 'assets/images/svg/profiles/ps/6600/002.svg',
        svgInterlock: 'assets/images/svg/profiles/ps/6600/003.svg',
        svgTransom: 'assets/images/svg/profiles/ps/all/004.svg',
        svgBeadSingle: 'assets/images/svg/profiles/ps/4800/008.svg',
        svgBeadDouble: 'assets/images/svg/profiles/ps/4800/009.svg',
        catalogUrl: 'https://drive.google.com/drive/search?q=PS+6600+profile',
        price: 3900,
        gwDeduct: 8.8,
        ghDeduct: 8.8,
        fixedGlassDeduct: 5.6,
        transomDeduct: 4.8,
        sashWOffset2: -0.4,
        sashWOffset3: 0.6,
        sashWOffset4: -0.2,
        sashHOffset: -5.8,
      ),
      _buildHingedSectorExact(
        id: 'sec_ps_5600',
        name: 'بي إس 5600 مفصلي كبير (PS 5600)',
        shortPdfName: 'مفصلي كبير P.S',
        group: 'قطاعات السلام (PS)',
        logo: 'assets/images/windows/systems/s000.png',
        svgFolder: 'assets/images/svg/profiles/ps/5600',
        svgFrameWithBar: 'assets/images/svg/profiles/ps/5600/006.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/ps/5600/005.svg',
        svgSashWindow: 'assets/images/svg/profiles/ps/5600/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/ps/5600/004.svg',
        svgPandaSash: 'assets/images/svg/profiles/ps/4800/001.svg',
        svgTransom: 'assets/images/svg/profiles/ps/5600/007.svg',
        svgBeadSingle: 'assets/images/svg/profiles/ps/5600/008.svg',
        svgBeadDouble: 'assets/images/svg/profiles/ps/5600/009.svg',
        svgBarTrim: 'assets/images/svg/profiles/ps/all/001.svg',
        catalogUrl: 'https://drive.google.com/drive/search?q=PS+5600+profile',
        price: 4000,
        gwDeduct: 8.5,
        ghDeduct: 8.5,
        fixedGlassDeduct: 5.8,
        transomDeduct: 5.0,
        sashWOffset1: -4.2,
        sashWOffset2: -2.6,
        sashWOffset4: -1.8,
        sashHOffset: -4.2,
      ),
      _buildHingedSectorExact(
        id: 'sec_ps_4800',
        name: 'بي إس 4800 مفصلي صغير (PS 4800)',
        shortPdfName: 'مفصلي صغير P.S',
        group: 'قطاعات السلام (PS)',
        logo: 'assets/images/windows/systems/s000.png',
        svgFolder: 'assets/images/svg/profiles/ps/4800',
        svgFrameWithBar: 'assets/images/svg/profiles/ps/4800/003.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/ps/4800/005.svg',
        svgSashWindow: 'assets/images/svg/profiles/ps/4800/001.svg',
        svgSashDoor: 'assets/images/svg/profiles/ps/4800/002.svg',
        svgPandaSash: 'assets/images/svg/profiles/ps/4800/001.svg',
        svgTransom: 'assets/images/svg/profiles/ps/4800/007.svg',
        svgBeadSingle: 'assets/images/svg/profiles/ps/4800/008.svg',
        svgBeadDouble: 'assets/images/svg/profiles/ps/4800/009.svg',
        svgBarTrim: 'assets/images/svg/profiles/ps/all/002.svg',
        catalogUrl: 'https://drive.google.com/drive/search?q=PS+4800+profile',
        price: 3800,
        gwDeduct: 8.0,
        ghDeduct: 8.0,
        fixedGlassDeduct: 5.2,
        transomDeduct: 4.5,
        sashWOffset1: -4.0,
        sashWOffset2: -2.4,
        sashWOffset4: -1.6,
        sashHOffset: -4.0,
      ),

      // ==================== 2. قطاعات الشريف (SH) ====================
      _buildSlidingSectorExact(
        id: 'sec_jumbo_100',
        name: 'جامبو 100 جرار (JamBo 100)',
        shortPdfName: 'جامبو 100',
        group: 'قطاعات الشريف',
        logo: 'assets/images/windows/systems/s001.png',
        svgFolder: 'assets/images/svg/profiles/sh/JamBo100',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/JamBo100/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/JamBo100/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/sh/JamBo100/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/JamBo100/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/JamBo100/004.svg',
        svgFlyScreen: 'assets/images/svg/profiles/sh/JamBo100/005.svg',
        svgInterlock: 'assets/images/svg/profiles/sh/JamBo100/006.svg',
        svgTransom: 'assets/images/svg/profiles/sh/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/all/011.svg',
        catalogUrl: 'https://mac-eg.com/',
        price: 4800,
        gwDeduct: 11.4,
        ghDeduct: 11.4,
        fixedGlassDeduct: 7.4,
        transomDeduct: 6.2,
        sashWOffset2: -1.5,
        sashWOffset3: -0.5,
        sashWOffset4: -1.0,
        sashHOffset: -8.2,
      ),
      _buildSlidingSectorExact(
        id: 'sec_tango_60',
        name: 'تانجو 60 جرار (Tango 60)',
        shortPdfName: 'تانجو 60',
        group: 'قطاعات الشريف',
        logo: 'assets/images/windows/systems/s001.png',
        svgFolder: 'assets/images/svg/profiles/sh/Tango60',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/Tango60/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/Tango60/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/sh/Tango60/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/Tango60/004.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/Tango60/005.svg',
        svgFlyScreen: 'assets/images/svg/profiles/sh/Tango60/006.svg',
        svgInterlock: 'assets/images/svg/profiles/sh/Tango60/008.svg',
        svgTransom: 'assets/images/svg/profiles/sh/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/all/011.svg',
        catalogUrl: 'https://mac-eg.com/',
        price: 4400,
        gwDeduct: 10.2,
        ghDeduct: 10.2,
        fixedGlassDeduct: 6.6,
        transomDeduct: 5.6,
        sashWOffset2: -1.2,
        sashWOffset3: -0.3,
        sashWOffset4: -0.8,
        sashHOffset: -7.5,
      ),
      _buildSlidingSectorExact(
        id: 'sec_tendu_120',
        name: 'تندو 120 جرار (TenDu 120)',
        shortPdfName: 'تندو 120',
        group: 'قطاعات الشريف',
        logo: 'assets/images/windows/systems/s001.png',
        svgFolder: 'assets/images/svg/profiles/sh/TenDu120',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/TenDu120/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/TenDu120/001.svg',
        svgFrame3Track: 'assets/images/svg/profiles/sh/JamBo100/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/TenDu120/002.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/TenDu120/003.svg',
        svgFlyScreen: 'assets/images/svg/profiles/sh/TenDu120/004.svg',
        svgInterlock: 'assets/images/svg/profiles/sh/TenDu120/005.svg',
        svgTransom: 'assets/images/svg/profiles/sh/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/all/011.svg',
        catalogUrl: 'https://mac-eg.com/',
        price: 5100,
        gwDeduct: 12.0,
        ghDeduct: 12.0,
        fixedGlassDeduct: 8.0,
        transomDeduct: 6.8,
        sashWOffset2: -1.8,
        sashWOffset3: -0.6,
        sashWOffset4: -1.2,
        sashHOffset: -9.0,
      ),
      _buildSlidingSectorExact(
        id: 'sec_tembo_84',
        name: 'تيمبو 84 جرار (TemBo 84)',
        shortPdfName: 'تيمبو 84',
        group: 'قطاعات الشريف',
        logo: 'assets/images/windows/systems/s001.png',
        svgFolder: 'assets/images/svg/profiles/sh/TemBo84',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/TemBo84/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/TemBo84/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/sh/TemBo84/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/TemBo84/004.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/TemBo84/005.svg',
        svgFlyScreen: 'assets/images/svg/profiles/sh/TemBo84/006.svg',
        svgInterlock: 'assets/images/svg/profiles/sh/TemBo84/007.svg',
        svgTransom: 'assets/images/svg/profiles/sh/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/all/011.svg',
        catalogUrl: 'https://mac-eg.com/',
        price: 4600,
        gwDeduct: 10.5,
        ghDeduct: 10.5,
        fixedGlassDeduct: 6.8,
        transomDeduct: 5.8,
        sashWOffset2: -1.4,
        sashWOffset3: -0.4,
        sashWOffset4: -0.9,
        sashHOffset: -8.0,
      ),
      _buildSlidingSectorExact(
        id: 'sec_nano_50',
        name: 'نانو 50 جرار (Nano 50)',
        shortPdfName: 'نانو 50',
        group: 'قطاعات الشريف',
        logo: 'assets/images/windows/systems/s001.png',
        svgFolder: 'assets/images/svg/profiles/sh/Nano50',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/Nano50/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/Nano50/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/sh/Nano50/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/Nano50/004.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/Nano50/004.svg',
        svgFlyScreen: 'assets/images/svg/profiles/sh/Nano50/005.svg',
        svgInterlock: 'assets/images/svg/profiles/sh/Nano50/006.svg',
        svgTransom: 'assets/images/svg/profiles/sh/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/all/011.svg',
        catalogUrl: 'https://mac-eg.com/',
        price: 4100,
        gwDeduct: 9.2,
        ghDeduct: 9.2,
        fixedGlassDeduct: 5.8,
        transomDeduct: 5.0,
        sashWOffset2: -1.0,
        sashWOffset3: -0.2,
        sashWOffset4: -0.6,
        sashHOffset: -6.5,
      ),
      _buildHingedSectorExact(
        id: 'sec_sonata_45',
        name: 'سوناتا 45 مفصلي (Sonata 45)',
        shortPdfName: 'سوناتا 45',
        group: 'قطاعات الشريف',
        logo: 'assets/images/windows/systems/s001.png',
        svgFolder: 'assets/images/svg/profiles/sh/Sonata45',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/Sonata45/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/Sonata45/008.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/Sonata45/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/Sonata45/004.svg',
        svgPandaSash: 'assets/images/svg/profiles/sh/Sonata45/003.svg',
        svgTransom: 'assets/images/svg/profiles/sh/Sonata45/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/Sonata45/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/Sonata45/011.svg',
        svgBarTrim: 'assets/images/svg/profiles/sh/all/002.svg',
        catalogUrl: 'https://mac-eg.com/',
        price: 4500,
        gwDeduct: 9.5,
        ghDeduct: 9.5,
        fixedGlassDeduct: 6.2,
        transomDeduct: 5.2,
        sashWOffset1: -4.8,
        sashWOffset2: -2.9,
        sashWOffset4: -2.0,
        sashHOffset: -4.8,
      ),

      // ==================== 3. فالف القباري (VALVE) ====================
      _buildSlidingSectorExact(
        id: 'sec_valve_v170',
        name: 'فالف V170 جرار بانوراما (VALVE V170)',
        shortPdfName: 'فالف V170',
        group: 'فالف القباري (VALVE)',
        logo: 'assets/images/windows/systems/s002.png',
        svgFolder: 'assets/images/svg/profiles/valve/V170',
        svgFrameWithBar: 'assets/images/svg/profiles/valve/V170/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/valve/MV100/007.svg',
        svgFrame3Track: 'assets/images/svg/profiles/valve/V170/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/valve/V170/004.svg',
        svgSashDoor: 'assets/images/svg/profiles/valve/V170/005.svg',
        svgFlyScreen: 'assets/images/svg/profiles/valve/V170/002.svg',
        svgInterlock: 'assets/images/svg/profiles/valve/V170/003.svg',
        svgTransom: 'assets/images/svg/profiles/valve/all/003.svg',
        svgBeadSingle: 'assets/images/svg/profiles/valve/all/006.svg',
        svgBeadDouble: 'assets/images/svg/profiles/valve/all/006.svg',
        catalogUrl: 'https://alkabbary.com/',
        price: 5600,
        gwDeduct: 12.8,
        ghDeduct: 12.8,
        fixedGlassDeduct: 8.2,
        transomDeduct: 6.8,
        sashWOffset2: -2.0,
        sashWOffset3: -0.8,
        sashWOffset4: -1.4,
        sashHOffset: -9.8,
      ),
      _buildSlidingSectorExact(
        id: 'sec_valve_v140',
        name: 'فالف V140 جرار (VALVE V140)',
        shortPdfName: 'فالف V140',
        group: 'فالف القباري (VALVE)',
        logo: 'assets/images/windows/systems/s002.png',
        svgFolder: 'assets/images/svg/profiles/valve/V140',
        svgFrameWithBar: 'assets/images/svg/profiles/valve/MV100/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/valve/V140/001.svg',
        svgFrame3Track: 'assets/images/svg/profiles/valve/V170/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/valve/V140/002.svg',
        svgSashDoor: 'assets/images/svg/profiles/valve/V140/003.svg',
        svgFlyScreen: 'assets/images/svg/profiles/valve/V140/004.svg',
        svgInterlock: 'assets/images/svg/profiles/valve/V140/006.svg',
        svgTransom: 'assets/images/svg/profiles/valve/all/003.svg',
        svgBeadSingle: 'assets/images/svg/profiles/valve/all/006.svg',
        svgBeadDouble: 'assets/images/svg/profiles/valve/all/006.svg',
        catalogUrl: 'https://alkabbary.com/',
        price: 5000,
        gwDeduct: 11.2,
        ghDeduct: 11.2,
        fixedGlassDeduct: 7.2,
        transomDeduct: 6.0,
        sashWOffset2: -1.5,
        sashWOffset3: -0.5,
        sashWOffset4: -1.0,
        sashHOffset: -8.4,
      ),
      _buildHingedSectorExact(
        id: 'sec_valve_mv100',
        name: 'فالف MV100 مفصلي / جرار (VALVE MV100)',
        shortPdfName: 'فالف MV100',
        group: 'فالف القباري (VALVE)',
        logo: 'assets/images/windows/systems/s002.png',
        svgFolder: 'assets/images/svg/profiles/valve/MV100',
        svgFrameWithBar: 'assets/images/svg/profiles/valve/MV100/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/valve/MV100/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/valve/MV100/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/valve/MV100/002.svg',
        svgPandaSash: 'assets/images/svg/profiles/valve/MV100/005.svg',
        svgTransom: 'assets/images/svg/profiles/valve/all/003.svg',
        svgBeadSingle: 'assets/images/svg/profiles/valve/all/006.svg',
        svgBeadDouble: 'assets/images/svg/profiles/valve/all/006.svg',
        svgBarTrim: 'assets/images/svg/profiles/valve/all/005.svg',
        catalogUrl: 'https://alkabbary.com/',
        price: 5100,
        gwDeduct: 10.5,
        ghDeduct: 10.5,
        fixedGlassDeduct: 6.8,
        transomDeduct: 5.8,
        sashWOffset1: -5.0,
        sashWOffset2: -3.0,
        sashWOffset4: -2.1,
        sashHOffset: -5.0,
      ),

      // ==================== 4. الدولية 21 - ماكسيم (Maxim) ====================
      _buildSlidingSectorExact(
        id: 'sec_maxim_e777',
        name: 'ماكسيم E777 جرار عريض (Maxim E777)',
        shortPdfName: 'ماكسيم E777',
        group: 'الدولية 21 - ماكسيم',
        logo: 'assets/images/windows/systems/s003.png',
        svgFolder: 'assets/images/svg/profiles/maxim/e777',
        svgFrameWithBar: 'assets/images/svg/profiles/maxim/e777/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/maxim/e777/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/maxim/e105/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/maxim/e777/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/maxim/e777/004.svg',
        svgFlyScreen: 'assets/images/svg/profiles/maxim/e777/006.svg',
        svgInterlock: 'assets/images/svg/profiles/maxim/e777/005.svg',
        svgTransom: 'assets/images/svg/profiles/maxim/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/maxim/all/004.svg',
        svgBeadDouble: 'assets/images/svg/profiles/maxim/all/003.svg',
        catalogUrl: 'https://dawlia21.com/',
        price: 4800,
        gwDeduct: 11.5,
        ghDeduct: 11.5,
        fixedGlassDeduct: 7.4,
        transomDeduct: 6.2,
        sashWOffset2: -1.6,
        sashWOffset3: -0.5,
        sashWOffset4: -1.1,
        sashHOffset: -8.5,
      ),
      _buildSlidingSectorExact(
        id: 'sec_maxim_e105',
        name: 'ماكسيم E105 جرار (Maxim E105)',
        shortPdfName: 'ماكسيم E105',
        group: 'الدولية 21 - ماكسيم',
        logo: 'assets/images/windows/systems/s003.png',
        svgFolder: 'assets/images/svg/profiles/maxim/e105',
        svgFrameWithBar: 'assets/images/svg/profiles/maxim/e105/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/maxim/e105/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/maxim/e105/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/maxim/e105/004.svg',
        svgSashDoor: 'assets/images/svg/profiles/maxim/e105/005.svg',
        svgFlyScreen: 'assets/images/svg/profiles/maxim/e105/007.svg',
        svgInterlock: 'assets/images/svg/profiles/maxim/e105/006.svg',
        svgTransom: 'assets/images/svg/profiles/maxim/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/maxim/all/004.svg',
        svgBeadDouble: 'assets/images/svg/profiles/maxim/all/003.svg',
        catalogUrl: 'https://dawlia21.com/',
        price: 4400,
        gwDeduct: 10.4,
        ghDeduct: 10.4,
        fixedGlassDeduct: 6.6,
        transomDeduct: 5.6,
        sashWOffset2: -1.2,
        sashWOffset3: -0.3,
        sashWOffset4: -0.8,
        sashHOffset: -7.8,
      ),
      _buildHingedSectorExact(
        id: 'sec_maxim_e47',
        name: 'إيكونومي E47 مفصلي كبير (Maxim E47)',
        shortPdfName: 'ماكسيم E47',
        group: 'الدولية 21 - ماكسيم',
        logo: 'assets/images/windows/systems/s003.png',
        svgFolder: 'assets/images/svg/profiles/maxim/e47',
        svgFrameWithBar: 'assets/images/svg/profiles/maxim/e47/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/maxim/e47/002.svg',
        svgSashWindow: 'assets/images/svg/profiles/maxim/e47/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/maxim/e47/005.svg',
        svgPandaSash: 'assets/images/svg/profiles/maxim/e37/003.svg',
        svgTransom: 'assets/images/svg/profiles/maxim/e47/004.svg',
        svgBeadSingle: 'assets/images/svg/profiles/maxim/all/004.svg',
        svgBeadDouble: 'assets/images/svg/profiles/maxim/all/003.svg',
        svgBarTrim: 'assets/images/svg/profiles/maxim/all/001.svg',
        catalogUrl: 'https://dawlia21.com/',
        price: 4500,
        gwDeduct: 9.8,
        ghDeduct: 9.8,
        fixedGlassDeduct: 6.2,
        transomDeduct: 5.2,
        sashWOffset1: -4.6,
        sashWOffset2: -2.8,
        sashWOffset4: -1.9,
        sashHOffset: -4.6,
      ),
      _buildHingedSectorExact(
        id: 'sec_maxim_e37',
        name: 'إيكونومي E37 مفصلي صغير (Maxim E37)',
        shortPdfName: 'ماكسيم E37',
        group: 'الدولية 21 - ماكسيم',
        logo: 'assets/images/windows/systems/s003.png',
        svgFolder: 'assets/images/svg/profiles/maxim/e37',
        svgFrameWithBar: 'assets/images/svg/profiles/maxim/e37/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/maxim/e37/002.svg',
        svgSashWindow: 'assets/images/svg/profiles/maxim/e37/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/maxim/e37/004.svg',
        svgPandaSash: 'assets/images/svg/profiles/maxim/e37/003.svg',
        svgTransom: 'assets/images/svg/profiles/maxim/e37/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/maxim/all/004.svg',
        svgBeadDouble: 'assets/images/svg/profiles/maxim/all/003.svg',
        svgBarTrim: 'assets/images/svg/profiles/maxim/all/002.svg',
        catalogUrl: 'https://dawlia21.com/',
        price: 4200,
        gwDeduct: 8.6,
        ghDeduct: 8.6,
        fixedGlassDeduct: 5.4,
        transomDeduct: 4.6,
        sashWOffset1: -4.0,
        sashWOffset2: -2.4,
        sashWOffset4: -1.6,
        sashHOffset: -4.0,
      ),

      // ==================== 5. قطاعات ألوميل (AluMil) ====================
      _buildSlidingSectorExact(
        id: 'sec_alumil_m12000',
        name: 'ألوميل M12000 جرار جامبو (AluMil M12000)',
        shortPdfName: 'ألوميل M12000',
        group: 'قطاعات ألوميل (AluMil)',
        logo: 'assets/images/windows/systems/s004.png',
        svgFolder: 'assets/images/svg/profiles/AluMil/M12000',
        svgFrameWithBar: 'assets/images/svg/profiles/AluMil/M12000/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/AluMil/M12000/001.svg',
        svgFrame3Track: 'assets/images/svg/profiles/AluMil/M12000/005.svg',
        svgSashWindow: 'assets/images/svg/profiles/AluMil/M12000/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/AluMil/M12000/003.svg',
        svgFlyScreen: 'assets/images/svg/profiles/AluMil/M12000/004.svg',
        svgInterlock: 'assets/images/svg/profiles/AluMil/M12000/002.svg',
        svgTransom: 'assets/images/svg/profiles/AluMil/all/006.svg',
        svgBeadSingle: 'assets/images/svg/profiles/AluMil/all/011.svg',
        svgBeadDouble: 'assets/images/svg/profiles/AluMil/all/009.svg',
        catalogUrl: 'https://www.alumil.com/egypt/ar/homeowners/products',
        price: 6200,
        gwDeduct: 13.0,
        ghDeduct: 13.0,
        fixedGlassDeduct: 8.4,
        transomDeduct: 7.0,
        sashWOffset2: -2.2,
        sashWOffset3: -0.9,
        sashWOffset4: -1.5,
        sashHOffset: -10.0,
      ),
      _buildSlidingSectorExact(
        id: 'sec_alumil_m9200',
        name: 'ألوميل M9200 جرار عازل (AluMil M9200)',
        shortPdfName: 'ألوميل M9200',
        group: 'قطاعات ألوميل (AluMil)',
        logo: 'assets/images/windows/systems/s004.png',
        svgFolder: 'assets/images/svg/profiles/AluMil/M9200',
        svgFrameWithBar: 'assets/images/svg/profiles/AluMil/M9200/005.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/AluMil/M9200/005.svg',
        svgFrame3Track: 'assets/images/svg/profiles/AluMil/M9200/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/AluMil/M9200/001.svg',
        svgSashDoor: 'assets/images/svg/profiles/AluMil/M9200/002.svg',
        svgFlyScreen: 'assets/images/svg/profiles/AluMil/M9200/004.svg',
        svgInterlock: 'assets/images/svg/profiles/AluMil/M9200/006.svg',
        svgTransom: 'assets/images/svg/profiles/AluMil/all/006.svg',
        svgBeadSingle: 'assets/images/svg/profiles/AluMil/all/011.svg',
        svgBeadDouble: 'assets/images/svg/profiles/AluMil/all/009.svg',
        catalogUrl: 'https://www.alumil.com/egypt/ar/homeowners/products',
        price: 5800,
        gwDeduct: 12.5,
        ghDeduct: 12.5,
        fixedGlassDeduct: 7.8,
        transomDeduct: 6.5,
        sashWOffset2: -2.0,
        sashWOffset3: -0.8,
        sashWOffset4: -1.4,
        sashHOffset: -9.5,
      ),
      _buildSlidingSectorExact(
        id: 'sec_alumil_m900',
        name: 'ألوميل M900 جرار (AluMil M900)',
        shortPdfName: 'ألوميل M900',
        group: 'قطاعات ألوميل (AluMil)',
        logo: 'assets/images/windows/systems/s004.png',
        svgFolder: 'assets/images/svg/profiles/AluMil/M900',
        svgFrameWithBar: 'assets/images/svg/profiles/AluMil/M900/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/AluMil/M900/004.svg',
        svgFrame3Track: 'assets/images/svg/profiles/AluMil/M9200/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/AluMil/M900/005.svg',
        svgSashDoor: 'assets/images/svg/profiles/AluMil/M900/010.svg',
        svgFlyScreen: 'assets/images/svg/profiles/AluMil/M900/002.svg',
        svgInterlock: 'assets/images/svg/profiles/AluMil/all/003.svg',
        svgTransom: 'assets/images/svg/profiles/AluMil/all/006.svg',
        svgBeadSingle: 'assets/images/svg/profiles/AluMil/all/011.svg',
        svgBeadDouble: 'assets/images/svg/profiles/AluMil/all/009.svg',
        catalogUrl: 'https://www.alumil.com/egypt/ar/homeowners/products',
        price: 5000,
        gwDeduct: 10.8,
        ghDeduct: 10.8,
        fixedGlassDeduct: 6.8,
        transomDeduct: 5.8,
        sashWOffset2: -1.4,
        sashWOffset3: -0.4,
        sashWOffset4: -0.9,
        sashHOffset: -8.0,
      ),
      _buildHingedSectorExact(
        id: 'sec_alumil_m9400',
        name: 'ألوميل M9400 مفصلي عازل (AluMil M9400)',
        shortPdfName: 'ألوميل M9400',
        group: 'قطاعات ألوميل (AluMil)',
        logo: 'assets/images/windows/systems/s004.png',
        svgFolder: 'assets/images/svg/profiles/AluMil/M9400',
        svgFrameWithBar: 'assets/images/svg/profiles/AluMil/M9400/007.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/AluMil/M9400/001.svg',
        svgSashWindow: 'assets/images/svg/profiles/AluMil/M9400/002.svg',
        svgSashDoor: 'assets/images/svg/profiles/AluMil/M9400/003.svg',
        svgPandaSash: 'assets/images/svg/profiles/AluMil/M940/004.svg',
        svgTransom: 'assets/images/svg/profiles/AluMil/M9400/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/AluMil/all/011.svg',
        svgBeadDouble: 'assets/images/svg/profiles/AluMil/all/009.svg',
        svgBarTrim: 'assets/images/svg/profiles/AluMil/all/008.svg',
        catalogUrl: 'https://www.alumil.com/egypt/ar/homeowners/products',
        price: 5600,
        gwDeduct: 11.0,
        ghDeduct: 11.0,
        fixedGlassDeduct: 7.0,
        transomDeduct: 6.0,
        sashWOffset1: -5.2,
        sashWOffset2: -3.1,
        sashWOffset4: -2.2,
        sashHOffset: -5.2,
      ),
      _buildHingedSectorExact(
        id: 'sec_alumil_m940',
        name: 'ألوميل M940 مفصلي (AluMil M940)',
        shortPdfName: 'ألوميل M940',
        group: 'قطاعات ألوميل (AluMil)',
        logo: 'assets/images/windows/systems/s004.png',
        svgFolder: 'assets/images/svg/profiles/AluMil/M940',
        svgFrameWithBar: 'assets/images/svg/profiles/AluMil/M940/005.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/AluMil/M940/002.svg',
        svgSashWindow: 'assets/images/svg/profiles/AluMil/M940/004.svg',
        svgSashDoor: 'assets/images/svg/profiles/AluMil/M940/001.svg',
        svgPandaSash: 'assets/images/svg/profiles/AluMil/M940/004.svg',
        svgTransom: 'assets/images/svg/profiles/AluMil/M940/003.svg',
        svgBeadSingle: 'assets/images/svg/profiles/AluMil/all/011.svg',
        svgBeadDouble: 'assets/images/svg/profiles/AluMil/all/009.svg',
        svgBarTrim: 'assets/images/svg/profiles/AluMil/all/008.svg',
        catalogUrl: 'https://www.alumil.com/egypt/ar/homeowners/products',
        price: 4900,
        gwDeduct: 9.6,
        ghDeduct: 9.6,
        fixedGlassDeduct: 6.0,
        transomDeduct: 5.0,
        sashWOffset1: -4.5,
        sashWOffset2: -2.7,
        sashWOffset4: -1.8,
        sashHOffset: -4.5,
      ),

      // ==================== 6. إيجماس - فولكانو (Volcano) ====================
      _buildSlidingSectorExact(
        id: 'sec_volcano_v120',
        name: 'فولكانو V120 جرار ثقيل (Volcano V120)',
        shortPdfName: 'فولكانو V120',
        group: 'إيجماس - فولكانو (Volcano)',
        logo: 'assets/images/windows/systems/s007.jpg',
        svgFolder: 'assets/images/svg/profiles/Volcano/V120',
        svgFrameWithBar: 'assets/images/svg/profiles/Volcano/V120/002.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/Volcano/V120/001.svg',
        svgFrame3Track: 'assets/images/svg/profiles/Volcano/V120/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/Volcano/V120/005.svg',
        svgSashDoor: 'assets/images/svg/profiles/Volcano/V120/004.svg',
        svgFlyScreen: 'assets/images/svg/profiles/Volcano/V120/007.svg',
        svgInterlock: 'assets/images/svg/profiles/Volcano/V120/006.svg',
        svgTransom: 'assets/images/svg/profiles/Volcano/all/007.svg',
        svgBeadSingle: 'assets/images/svg/profiles/Volcano/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/Volcano/all/009.svg',
        catalogUrl: 'https://egmas.com/',
        price: 5300,
        gwDeduct: 12.0,
        ghDeduct: 12.0,
        fixedGlassDeduct: 7.8,
        transomDeduct: 6.5,
        sashWOffset2: -1.8,
        sashWOffset3: -0.6,
        sashWOffset4: -1.2,
        sashHOffset: -9.0,
      ),
      _buildSlidingSectorExact(
        id: 'sec_volcano_v70',
        name: 'فولكانو V70 جرار وسط (Volcano V70)',
        shortPdfName: 'فولكانو V70',
        group: 'إيجماس - فولكانو (Volcano)',
        logo: 'assets/images/windows/systems/s007.jpg',
        svgFolder: 'assets/images/svg/profiles/Volcano/V70',
        svgFrameWithBar: 'assets/images/svg/profiles/Volcano/V70/007.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/Volcano/V70/001.svg',
        svgFrame3Track: 'assets/images/svg/profiles/Volcano/V120/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/Volcano/V70/002.svg',
        svgSashDoor: 'assets/images/svg/profiles/Volcano/V70/003.svg',
        svgFlyScreen: 'assets/images/svg/profiles/Volcano/V70/005.svg',
        svgInterlock: 'assets/images/svg/profiles/Volcano/V120/006.svg',
        svgTransom: 'assets/images/svg/profiles/Volcano/all/007.svg',
        svgBeadSingle: 'assets/images/svg/profiles/Volcano/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/Volcano/all/009.svg',
        catalogUrl: 'https://egmas.com/',
        price: 4700,
        gwDeduct: 10.5,
        ghDeduct: 10.5,
        fixedGlassDeduct: 6.8,
        transomDeduct: 5.8,
        sashWOffset2: -1.4,
        sashWOffset3: -0.4,
        sashWOffset4: -0.9,
        sashHOffset: -7.8,
      ),
      _buildHingedSectorExact(
        id: 'sec_volcano_v44',
        name: 'فولكانو V44 مفصلي (Volcano V44)',
        shortPdfName: 'فولكانو V44',
        group: 'إيجماس - فولكانو (Volcano)',
        logo: 'assets/images/windows/systems/s007.jpg',
        svgFolder: 'assets/images/svg/profiles/Volcano/V44',
        svgFrameWithBar: 'assets/images/svg/profiles/Volcano/V44/002.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/Volcano/V44/001.svg',
        svgSashWindow: 'assets/images/svg/profiles/Volcano/V44/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/Volcano/V44/004.svg',
        svgPandaSash: 'assets/images/svg/profiles/Volcano/V44/003.svg',
        svgTransom: 'assets/images/svg/profiles/Volcano/all/007.svg',
        svgBeadSingle: 'assets/images/svg/profiles/Volcano/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/Volcano/all/009.svg',
        svgBarTrim: 'assets/images/svg/profiles/Volcano/all/001.svg',
        catalogUrl: 'https://egmas.com/',
        price: 4600,
        gwDeduct: 10.0,
        ghDeduct: 10.0,
        fixedGlassDeduct: 6.4,
        transomDeduct: 5.4,
        sashWOffset1: -4.8,
        sashWOffset2: -2.9,
        sashWOffset4: -2.0,
        sashHOffset: -4.8,
      ),

      // ==================== 7. قطاعات UPVC المصري (Emapen) ====================
      _buildSlidingSectorExact(
        id: 'sec_upvc_eg_large_sliding',
        name: 'إيمابن UPVC كبير جرار (Emapen Large)',
        shortPdfName: 'UPVC كبير',
        group: 'قطاعات UPVC المصري (Emapen)',
        logo: 'assets/images/windows/systems/upvc_eg.jpg',
        svgFolder: 'assets/images/svg/profiles/sh/JamBo100',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/JamBo100/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/JamBo100/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/sh/JamBo100/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/JamBo100/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/JamBo100/004.svg',
        svgFlyScreen: 'assets/images/svg/profiles/sh/JamBo100/005.svg',
        svgInterlock: 'assets/images/svg/profiles/sh/JamBo100/006.svg',
        svgTransom: 'assets/images/svg/profiles/sh/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/all/011.svg',
        catalogUrl: 'https://emapen.com/',
        price: 4500,
        gwDeduct: 13.0,
        ghDeduct: 13.0,
        fixedGlassDeduct: 8.2,
        transomDeduct: 6.8,
        sashWOffset2: -2.0,
        sashWOffset3: -0.7,
        sashWOffset4: -1.3,
        sashHOffset: -10.0,
      ),
      _buildSlidingSectorExact(
        id: 'sec_upvc_eg_small_sliding',
        name: 'إيمابن UPVC صغير جرار (Emapen Small)',
        shortPdfName: 'UPVC صغير',
        group: 'قطاعات UPVC المصري (Emapen)',
        logo: 'assets/images/windows/systems/upvc_eg.jpg',
        svgFolder: 'assets/images/svg/profiles/sh/Tango60',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/Tango60/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/Tango60/002.svg',
        svgFrame3Track: 'assets/images/svg/profiles/sh/Tango60/003.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/Tango60/004.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/Tango60/005.svg',
        svgFlyScreen: 'assets/images/svg/profiles/sh/Tango60/006.svg',
        svgInterlock: 'assets/images/svg/profiles/sh/Tango60/008.svg',
        svgTransom: 'assets/images/svg/profiles/sh/all/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/all/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/all/011.svg',
        catalogUrl: 'https://emapen.com/',
        price: 4000,
        gwDeduct: 11.5,
        ghDeduct: 11.5,
        fixedGlassDeduct: 7.2,
        transomDeduct: 6.0,
        sashWOffset2: -1.5,
        sashWOffset3: -0.5,
        sashWOffset4: -1.0,
        sashHOffset: -8.5,
      ),
      _buildHingedSectorExact(
        id: 'sec_upvc_eg_hinged',
        name: 'إيمابن UPVC مفصلي / قلاب كبير (Emapen)',
        shortPdfName: 'UPVC كبير',
        group: 'قطاعات UPVC المصري (Emapen)',
        logo: 'assets/images/windows/systems/upvc_eg.jpg',
        svgFolder: 'assets/images/svg/profiles/sh/Sonata45',
        svgFrameWithBar: 'assets/images/svg/profiles/sh/Sonata45/001.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/sh/Sonata45/008.svg',
        svgSashWindow: 'assets/images/svg/profiles/sh/Sonata45/003.svg',
        svgSashDoor: 'assets/images/svg/profiles/sh/Sonata45/004.svg',
        svgPandaSash: 'assets/images/svg/profiles/sh/Sonata45/003.svg',
        svgTransom: 'assets/images/svg/profiles/sh/Sonata45/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/sh/Sonata45/010.svg',
        svgBeadDouble: 'assets/images/svg/profiles/sh/Sonata45/011.svg',
        svgBarTrim: 'assets/images/svg/profiles/sh/all/002.svg',
        catalogUrl: 'https://emapen.com/',
        price: 4000,
        gwDeduct: 11.8,
        ghDeduct: 11.8,
        fixedGlassDeduct: 7.4,
        transomDeduct: 6.2,
        sashWOffset1: -5.2,
        sashWOffset2: -3.1,
        sashWOffset4: -2.2,
        sashHOffset: -5.2,
      ),

      // ==================== 8. قطاعات UPVC المستورد ====================
      _buildSlidingSectorExact(
        id: 'sec_upvc_tr_sliding',
        name: 'وينتك / كومبن UPVC تركي جرار (Wintech)',
        shortPdfName: 'UPVC تركي جرار',
        group: 'قطاعات UPVC المستورد',
        logo: 'assets/images/windows/systems/s005.png',
        svgFolder: 'assets/images/svg/profiles/AluMil/M9200',
        svgFrameWithBar: 'assets/images/svg/profiles/AluMil/M9200/005.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/AluMil/M9200/005.svg',
        svgFrame3Track: 'assets/images/svg/profiles/AluMil/M9200/007.svg',
        svgSashWindow: 'assets/images/svg/profiles/AluMil/M9200/001.svg',
        svgSashDoor: 'assets/images/svg/profiles/AluMil/M9200/002.svg',
        svgFlyScreen: 'assets/images/svg/profiles/AluMil/M9200/004.svg',
        svgInterlock: 'assets/images/svg/profiles/AluMil/M9200/006.svg',
        svgTransom: 'assets/images/svg/profiles/AluMil/all/006.svg',
        svgBeadSingle: 'assets/images/svg/profiles/AluMil/all/011.svg',
        svgBeadDouble: 'assets/images/svg/profiles/AluMil/all/009.svg',
        catalogUrl: 'https://www.wintech.com.tr/',
        price: 5500,
        gwDeduct: 13.5,
        ghDeduct: 13.5,
        fixedGlassDeduct: 8.6,
        transomDeduct: 7.2,
        sashWOffset2: -2.0,
        sashWOffset3: -0.7,
        sashWOffset4: -1.4,
        sashHOffset: -10.2,
      ),
      _buildHingedSectorExact(
        id: 'sec_upvc_tr_hinged',
        name: 'وينتك / كومبن UPVC تركي مفصلي (Wintech)',
        shortPdfName: 'UPVC تركي مفصلي',
        group: 'قطاعات UPVC المستورد',
        logo: 'assets/images/windows/systems/s005.png',
        svgFolder: 'assets/images/svg/profiles/AluMil/M9400',
        svgFrameWithBar: 'assets/images/svg/profiles/AluMil/M9400/007.svg',
        svgFrameWithoutBar: 'assets/images/svg/profiles/AluMil/M9400/001.svg',
        svgSashWindow: 'assets/images/svg/profiles/AluMil/M9400/002.svg',
        svgSashDoor: 'assets/images/svg/profiles/AluMil/M9400/003.svg',
        svgPandaSash: 'assets/images/svg/profiles/AluMil/M940/004.svg',
        svgTransom: 'assets/images/svg/profiles/AluMil/M9400/005.svg',
        svgBeadSingle: 'assets/images/svg/profiles/AluMil/all/011.svg',
        svgBeadDouble: 'assets/images/svg/profiles/AluMil/all/009.svg',
        svgBarTrim: 'assets/images/svg/profiles/AluMil/all/008.svg',
        catalogUrl: 'https://www.wintech.com.tr/',
        price: 5300,
        gwDeduct: 12.2,
        ghDeduct: 12.2,
        fixedGlassDeduct: 7.8,
        transomDeduct: 6.4,
        sashWOffset1: -5.5,
        sashWOffset2: -3.3,
        sashWOffset4: -2.3,
        sashHOffset: -5.5,
      ),
    ];
  }


  /// قائمة أنواع الزجاج (مع جعل "الازاز العاكس البني" هو الديفولت الطبيعي الذي يُبنى عليه سعر المتر المسطح)
  List<GlassTypeItem> _defaultGlassTypes() {
    return [
      GlassTypeItem(
        id: 'g_single_ref_brown_6',
        name: 'عاكس بني 6 مم (الافتراضي الأساسي)',
        pricePerSquareMeter: 600.0,
        thickness: '6 مم',
        color: 'عاكس بني',
        isDoublePreset: false,
        isDefaultBaseline: true,
      ),
      GlassTypeItem(
        id: 'g_single_ref_blue_6',
        name: 'عاكس أزرق 6 مم',
        pricePerSquareMeter: 650.0,
        thickness: '6 مم',
        color: 'عاكس أزرق',
        isDoublePreset: false,
      ),
      GlassTypeItem(
        id: 'g_single_ref_green_6',
        name: 'عاكس أخضر 6 مم',
        pricePerSquareMeter: 620.0,
        thickness: '6 مم',
        color: 'عاكس أخضر',
        isDoublePreset: false,
      ),
      GlassTypeItem(
        id: 'g_single_clear_6',
        name: 'شفاف 6 مم',
        pricePerSquareMeter: 450.0,
        thickness: '6 مم',
        color: 'شفاف',
        isDoublePreset: false,
      ),
      GlassTypeItem(
        id: 'g_single_frosted',
        name: 'مصنفر 6 مم',
        pricePerSquareMeter: 500.0,
        thickness: '6 مم',
        color: 'مصنفر',
        isDoublePreset: false,
      ),
      GlassTypeItem(
        id: 'g_single_fume_6',
        name: 'فاميه غامق 6 مم',
        pricePerSquareMeter: 550.0,
        thickness: '6 مم',
        color: 'فاميه',
        isDoublePreset: false,
      ),
      GlassTypeItem(
        id: 'g_tempered_10',
        name: 'زجاج سيكوريت 10 مم',
        pricePerSquareMeter: 1250.0,
        thickness: '10 مم',
        color: 'سيكوريت',
        isDoublePreset: false,
      ),
    ];
  }

  /// قائمة الإكسسوارات الكاملة (رينو، عضم، ميجا، تراك، مانع ارتجاج، عجل، مقابض، كوالين، مفصلات، كاوتش، فرش...)
  List<AccessoryPriceItem> _defaultAccessories() {
    return [
      AccessoryPriceItem(
          id: 'acc_reno_90',
          name: 'رينو — زاوية تجميع قطاعات 90 درجة (Reno)',
          unit: 'قطعة',
          price: 25.0),
      AccessoryPriceItem(
          id: 'acc_adhm_corner',
          name: 'عضم تجميع وزوايا سلك وباكتات (عضم 90)',
          unit: 'قطعة',
          price: 10.0),
      AccessoryPriceItem(
          id: 'acc_handle_sliding',
          name: 'ميجا — طقم صكاك / مقبض جرار أوتوماتيك (Mega)',
          unit: 'طقم',
          price: 180.0),
      AccessoryPriceItem(
          id: 'acc_track_mech',
          name: 'تراك — إكسسوار تراك ومجرى حركة (Track)',
          unit: 'طقم',
          price: 95.0),
      AccessoryPriceItem(
          id: 'acc_anti_rattle',
          name: 'مانع ارتجاج ودليل علوي للضلف الجرار',
          unit: 'قطعة',
          price: 15.0),
      AccessoryPriceItem(
          id: 'acc_rollers_double',
          name: 'طقم عجل جرار دبل روحين بالرمان بلي',
          unit: 'طقم',
          price: 160.0),
      AccessoryPriceItem(
          id: 'acc_screen_rollers',
          name: 'طقم عجل ضلفة سلك جرار',
          unit: 'طقم',
          price: 45.0),
      AccessoryPriceItem(
          id: 'acc_handle_hinged',
          name: 'مقبض مفصلي / قلاب تركي بالماكينة',
          unit: 'طقم',
          price: 220.0),
      AccessoryPriceItem(
          id: 'acc_handle_panda',
          name: 'طقم مقبض ومفصلات نظام باندا (Panda)',
          unit: 'طقم',
          price: 260.0),
      AccessoryPriceItem(
          id: 'acc_door_lock',
          name: 'كالون ومقبض باب ألوميتال سلندر بمفتاح',
          unit: 'طقم',
          price: 450.0),
      AccessoryPriceItem(
          id: 'acc_hinges_pair',
          name: 'طقم مفصلات إيطالي / تركي ثقيل للشباك',
          unit: 'طقم',
          price: 120.0),
      AccessoryPriceItem(
          id: 'acc_door_hinges',
          name: 'طقم مفصلات باب ثقيلة ثلاثية',
          unit: 'طقم',
          price: 280.0),
      AccessoryPriceItem(
          id: 'acc_stoppers_caps',
          name: 'صدادات جرار وكابات تصريف مياه',
          unit: 'طقم',
          price: 20.0),
      AccessoryPriceItem(
          id: 'acc_fly_mesh',
          name: 'سلك فايبر / ألومنيوم بالفرش والكاوتش',
          unit: 'متر مربع',
          price: 250.0),
      AccessoryPriceItem(
          id: 'acc_rubber_gasket',
          name: 'كاوتش EPDM عازل للزجاج والضلف',
          unit: 'متر طولي',
          price: 15.0),
      AccessoryPriceItem(
          id: 'acc_brush_seal',
          name: 'فرش عازل للأتربة جرار',
          unit: 'متر طولي',
          price: 12.0),
    ];
  }

  static String _resolveCompanyHConnectorSvg(String svgFolder) {
    if (svgFolder.contains('/ps/')) return 'assets/images/svg/profiles/ps/all/007.svg';
    if (svgFolder.contains('/sh/')) return 'assets/images/svg/profiles/sh/Sonata45/012.svg';
    if (svgFolder.contains('/valve/')) return 'assets/images/svg/profiles/valve/all/003.svg';
    if (svgFolder.contains('/maxim/')) return 'assets/images/svg/profiles/maxim/e105/010.svg';
    if (svgFolder.contains('/AluMil/')) return 'assets/images/svg/profiles/AluMil/M900/006.svg';
    return 'assets/images/svg/profiles/Volcano/all/001.svg';
  }

  static String _resolveCompanyArchitraveBarSvg(String svgFolder) {
    if (svgFolder.contains('/ps/')) return 'assets/images/svg/profiles/ps/all/001.svg';
    if (svgFolder.contains('/sh/')) return 'assets/images/svg/profiles/sh/all/002.svg';
    if (svgFolder.contains('/valve/')) return 'assets/images/svg/profiles/valve/all/005.svg';
    if (svgFolder.contains('/maxim/')) return 'assets/images/svg/profiles/maxim/all/010.svg';
    if (svgFolder.contains('/AluMil/')) return 'assets/images/svg/profiles/AluMil/all/008.svg';
    return 'assets/images/svg/profiles/Volcano/all/005.svg';
  }

  static String _resolveCompanyDoorKickplateSvg(String svgFolder) {
    if (svgFolder.contains('/ps/')) return 'assets/images/svg/profiles/ps/5600/001.svg';
    if (svgFolder.contains('/sh/')) return 'assets/images/svg/profiles/sh/all/006.svg';
    if (svgFolder.contains('/valve/')) return 'assets/images/svg/profiles/valve/all/009.svg';
    if (svgFolder.contains('/maxim/')) return 'assets/images/svg/profiles/maxim/all/006.svg';
    if (svgFolder.contains('/AluMil/')) return 'assets/images/svg/profiles/AluMil/all/007.svg';
    return 'assets/images/svg/profiles/Volcano/all/008.svg';
  }

  static SectorProfile _buildSlidingSectorExact({
    required String id,
    required String name,
    required String shortPdfName,
    required String group,
    required String logo,
    required String svgFolder,
    required String svgFrameWithBar,
    required String svgFrameWithoutBar,
    required String svgFrame3Track,
    required String svgSashWindow,
    required String svgSashDoor,
    required String svgFlyScreen,
    required String svgInterlock,
    required String svgTransom,
    required String svgBeadSingle,
    required String svgBeadDouble,
    required String catalogUrl,
    required double price,
    required double gwDeduct,
    required double ghDeduct,
    required double fixedGlassDeduct,
    required double transomDeduct,
    required double sashWOffset2,
    required double sashWOffset3,
    required double sashWOffset4,
    required double sashHOffset,
  }) {
    return SectorProfile(
      id: id,
      name: name,
      shortPdfName: shortPdfName,
      category: 'منزلق',
      companyGroup: group,
      systemType: 'شباك جرار',
      defaultSashCount: 2,
      companyLogoAsset: logo,
      profileSvgFolder: svgFolder,
      fixedTransomSvg: svgTransom,
      fixedBeadSingleSvg: svgBeadSingle,
      fixedBeadDoubleSvg: svgBeadDouble,
      hConnectorSvg: _resolveCompanyHConnectorSvg(svgFolder),
      architraveBarSvg: _resolveCompanyArchitraveBarSvg(svgFolder),
      doorKickplateSvg: _resolveCompanyDoorKickplateSvg(svgFolder),
      catalogUrl: catalogUrl,
      pricePerSquareMeter: price,
      glassWidthDeductCm: gwDeduct,
      glassHeightDeductCm: ghDeduct,
      fixedGlassDeductCm: fixedGlassDeduct,
      transomDeductCm: transomDeduct,
      parts: [
        SectorPart(
          id: '${id}_p1',
          name: 'حلق جرار ببار (عرض)',
          role: 'حلق',
          dimensionBasis: 'width',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithBar,
          condition: 'with_bar',
        ),
        SectorPart(
          id: '${id}_p2',
          name: 'حلق جرار ببار (ارتفاع)',
          role: 'حلق',
          dimensionBasis: 'height',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithBar,
          condition: 'with_bar',
        ),
        SectorPart(
          id: '${id}_p3',
          name: 'حلق جرار بدون بار (عرض)',
          role: 'حلق',
          dimensionBasis: 'width',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithoutBar,
          condition: 'without_bar',
        ),
        SectorPart(
          id: '${id}_p4',
          name: 'حلق جرار بدون بار (ارتفاع)',
          role: 'حلق',
          dimensionBasis: 'height',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithoutBar,
          condition: 'without_bar',
        ),
        SectorPart(
          id: '${id}_p5',
          name: 'ضلفة شباك جرار (عرض)',
          role: 'ضلفة',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2,
          offset1SashCm: sashWOffset2,
          offset3SashCm: sashWOffset3,
          offset4SashCm: sashWOffset4,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashWindow,
          condition: 'window_only',
        ),
        SectorPart(
          id: '${id}_p6',
          name: 'ضلفة شباك جرار (ارتفاع)',
          role: 'ضلفة',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashWindow,
          condition: 'window_only',
        ),
        SectorPart(
          id: '${id}_p7',
          name: 'ضلفة باب جرار (عرض)',
          role: 'ضلفة',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2,
          offset1SashCm: sashWOffset2,
          offset3SashCm: sashWOffset3,
          offset4SashCm: sashWOffset4,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashDoor,
          condition: 'door_only',
        ),
        SectorPart(
          id: '${id}_p8',
          name: 'ضلفة باب جرار (ارتفاع)',
          role: 'ضلفة',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashDoor,
          condition: 'door_only',
        ),
        SectorPart(
          id: '${id}_p9',
          name: 'سكينة تداخل (ارتفاع)',
          role: 'سكينة',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset,
          quantityPerWindow: 1,
          multiplyBySashes: true,
          svgAssetPath: svgInterlock,
        ),
        SectorPart(
          id: '${id}_p10',
          name: 'ضلفة سلك جرار (عرض)',
          role: 'منخل',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2 + 1.5,
          offset3SashCm: sashWOffset3 + 1.5,
          offset4SashCm: sashWOffset4 + 1.5,
          quantityPerWindow: 2,
          svgAssetPath: svgFlyScreen,
          condition: 'fly_screen',
        ),
        SectorPart(
          id: '${id}_p11',
          name: 'ضلفة سلك جرار (ارتفاع)',
          role: 'منخل',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset + 1.5,
          quantityPerWindow: 2,
          svgAssetPath: svgFlyScreen,
          condition: 'fly_screen',
        ),
      ],
    );
  }

  static SectorProfile _buildHingedSectorExact({
    required String id,
    required String name,
    required String shortPdfName,
    required String group,
    required String logo,
    required String svgFolder,
    required String svgFrameWithBar,
    required String svgFrameWithoutBar,
    required String svgSashWindow,
    required String svgSashDoor,
    required String svgPandaSash,
    required String svgTransom,
    required String svgBeadSingle,
    required String svgBeadDouble,
    required String svgBarTrim,
    required String catalogUrl,
    required double price,
    required double gwDeduct,
    required double ghDeduct,
    required double fixedGlassDeduct,
    required double transomDeduct,
    required double sashWOffset1,
    required double sashWOffset2,
    required double sashWOffset4,
    required double sashHOffset,
  }) {
    return SectorProfile(
      id: id,
      name: name,
      shortPdfName: shortPdfName,
      category: 'مفصلي',
      companyGroup: group,
      systemType: 'شباك مفصلي',
      defaultSashCount: 1,
      companyLogoAsset: logo,
      profileSvgFolder: svgFolder,
      fixedTransomSvg: svgTransom,
      fixedBeadSingleSvg: svgBeadSingle,
      fixedBeadDoubleSvg: svgBeadDouble,
      hConnectorSvg: _resolveCompanyHConnectorSvg(svgFolder),
      architraveBarSvg: svgBarTrim,
      doorKickplateSvg: _resolveCompanyDoorKickplateSvg(svgFolder),
      catalogUrl: catalogUrl,
      pricePerSquareMeter: price,
      glassWidthDeductCm: gwDeduct,
      glassHeightDeductCm: ghDeduct,
      fixedGlassDeductCm: fixedGlassDeduct,
      transomDeductCm: transomDeduct,
      parts: [
        SectorPart(
          id: '${id}_h1',
          name: 'حلق مفصلي ببار (عرض)',
          role: 'حلق',
          dimensionBasis: 'width',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithBar,
          condition: 'with_bar',
        ),
        SectorPart(
          id: '${id}_h2',
          name: 'حلق مفصلي ببار (ارتفاع)',
          role: 'حلق',
          dimensionBasis: 'height',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithBar,
          condition: 'with_bar',
        ),
        SectorPart(
          id: '${id}_h3',
          name: 'حلق مفصلي بدون بار (عرض)',
          role: 'حلق',
          dimensionBasis: 'width',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithoutBar,
          condition: 'without_bar',
        ),
        SectorPart(
          id: '${id}_h4',
          name: 'حلق مفصلي بدون بار (ارتفاع)',
          role: 'حلق',
          dimensionBasis: 'height',
          offsetCm: 0.0,
          quantityPerWindow: 2,
          svgAssetPath: svgFrameWithoutBar,
          condition: 'without_bar',
        ),
        SectorPart(
          id: '${id}_h5',
          name: 'ضلفة شباك مفصلي (عرض)',
          role: 'ضلفة',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2,
          offset1SashCm: sashWOffset1,
          offset3SashCm: sashWOffset2,
          offset4SashCm: sashWOffset4,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashWindow,
          condition: 'window_only',
        ),
        SectorPart(
          id: '${id}_h6',
          name: 'ضلفة شباك مفصلي (ارتفاع)',
          role: 'ضلفة',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashWindow,
          condition: 'window_only',
        ),
        SectorPart(
          id: '${id}_h7',
          name: 'ضلفة باب مفصلي (عرض)',
          role: 'ضلفة',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2,
          offset1SashCm: sashWOffset1,
          offset3SashCm: sashWOffset2,
          offset4SashCm: sashWOffset4,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashDoor,
          condition: 'door_only',
        ),
        SectorPart(
          id: '${id}_h8',
          name: 'ضلفة باب مفصلي (ارتفاع)',
          role: 'ضلفة',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgSashDoor,
          condition: 'door_only',
        ),
        SectorPart(
          id: '${id}_h9',
          name: 'ضلفة سلك نظام باندا خلفية (عرض)',
          role: 'باندا',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2 - 3.5,
          offset1SashCm: sashWOffset1 - 3.5,
          offset3SashCm: sashWOffset2 - 3.5,
          offset4SashCm: sashWOffset4 - 3.5,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgPandaSash,
          condition: 'panda_only',
        ),
        SectorPart(
          id: '${id}_h10',
          name: 'ضلفة سلك نظام باندا خلفية (ارتفاع)',
          role: 'باندا',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset - 3.5,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgPandaSash,
          condition: 'panda_only',
        ),
        SectorPart(
          id: '${id}_h11',
          name: 'باكتة زجاج سنجل (عرض)',
          role: 'باكتة',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2 - gwDeduct,
          offset1SashCm: sashWOffset1 - gwDeduct,
          offset4SashCm: sashWOffset4 - gwDeduct,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgBeadSingle,
          condition: 'single_glass',
        ),
        SectorPart(
          id: '${id}_h12',
          name: 'باكتة زجاج سنجل (ارتفاع)',
          role: 'باكتة',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset - ghDeduct,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgBeadSingle,
          condition: 'single_glass',
        ),
        SectorPart(
          id: '${id}_h13',
          name: 'باكتة زجاج دبل (عرض)',
          role: 'باكتة',
          dimensionBasis: 'net_width_per_sash',
          offsetCm: sashWOffset2 - gwDeduct,
          offset1SashCm: sashWOffset1 - gwDeduct,
          offset4SashCm: sashWOffset4 - gwDeduct,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgBeadDouble,
          condition: 'double_glass',
        ),
        SectorPart(
          id: '${id}_h14',
          name: 'باكتة زجاج دبل (ارتفاع)',
          role: 'باكتة',
          dimensionBasis: 'net_height',
          offsetCm: sashHOffset - ghDeduct,
          quantityPerWindow: 2,
          multiplyBySashes: true,
          svgAssetPath: svgBeadDouble,
          condition: 'double_glass',
        ),
      ],
    );
  }
}
