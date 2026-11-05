import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/workshop_models.dart';
import '../services/native_file_service.dart';
import '../services/workshop_storage.dart';
import '../widgets/svg_profile_widget.dart';
import '../widgets/window_2d_visualizer.dart';

/// شاشة تصميم ومعاينة الشباك / الباب التفاعلية:
/// واجهة المعاينة مثبتة ومفصولة تماماً في الأعلى، والقائمة السفلية قابلة للتمرير بحرية مع رؤية التأثير اللحظي!
class WindowDesignerScreen extends StatefulWidget {
  final WorkshopStorage storage;
  final ClientWindowItem? existingItem;
  final int nextIndex;
  final String? initialCategory; // منزلق | مفصلي
  final String? initialCompanyGroup;
  final SectorProfile? initialSector;
  final String? initialUnitType; // شباك | باب

  const WindowDesignerScreen({
    super.key,
    required this.storage,
    this.existingItem,
    this.nextIndex = 1,
    this.initialCategory,
    this.initialCompanyGroup,
    this.initialSector,
    this.initialUnitType,
  });

  @override
  State<WindowDesignerScreen> createState() => _WindowDesignerScreenState();
}

class _WindowDesignerScreenState extends State<WindowDesignerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _optionsTabController;

  late String _selectedCategory; // منزلق | مفصلي
  late SectorProfile _selectedSector;

  late TextEditingController _labelCtrl;
  late TextEditingController _widthCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _pricePerM2Ctrl;
  late TextEditingController _customPdfDescCtrl;

  String _unitType = 'شباك';
  String _openType = 'جرار';
  String _barType = 'ببار';
  String _openDirection = 'يمين للداخل';
  String _sectorColor = 'بيج';
  int _sashCount = 2;
  int _trackCount = 2;
  bool _hasFlyScreen = true;
  bool _hasPanda = false; // نظام الباندا للمفصلي (يحسب المتر × 1.5)
  bool _isCombinedMeterPrice = false;

  // خصائص الدوران العلوي (القوس) تحت أبعاد الشباك
  bool _hasArch = false;
  late TextEditingController _archWidthCtrl;
  late TextEditingController _archHeightCtrl;
  late TextEditingController _archPriceCtrl;

  // خصائص قسم الأبواب
  bool _hasDoorKickplate = true;
  late TextEditingController _doorKickHeightCtrl;
  bool _hasDoorMiddleMullion = true;
  String _doorBottomPanelType = 'حشو فايبر / شرائح ألومنيوم';

  // الثوابت وأماكنها ومقاساتها (شمال، يمين، فوق، تحت)
  bool _hasLeftFixed = false;
  late TextEditingController _leftFixedWCtrl;
  int _leftFixedSplits = 1;

  bool _hasRightFixed = false;
  late TextEditingController _rightFixedWCtrl;
  int _rightFixedSplits = 1;

  bool _hasTopFixed = false;
  late TextEditingController _topFixedHCtrl;
  int _topFixedSplits = 1;

  bool _hasBottomFixed = false;
  late TextEditingController _bottomFixedHCtrl;
  int _bottomFixedSplits = 1;

  // الشفاط (يركب في الثوابت فقط، وإذا كان الثابت مقسماً يوضع في جزء واحد منه)
  bool _hasExhaustFan = false;
  String _exhaustFanShape = 'دائري';
  late TextEditingController _exhaustFanDiamCtrl;
  String _exhaustFanPosition = 'في الثابت العلوي';
  int _exhaustFanPartIndex = 0;

  // الزجاج (الافتراضي: الزجاج العاكس البني) والجورجيا
  bool _hasGlass = true;
  bool _isDoubleGlass = false;
  late GlassTypeItem _selectedGlass1;
  late GlassTypeItem _selectedGlass2;
  late TextEditingController _customGlassTextCtrl;

  bool _hasGeorgian = false;
  late TextEditingController _georgianMetersCtrl;

  static const List<String> _validExhaustPositions = [
    'في الثابت العلوي',
    'في الثابت السفلي',
    'في الثابت اليمين',
    'في الثابت الشمال',
  ];

  @override
  void initState() {
    super.initState();
    _optionsTabController = TabController(length: 4, vsync: this);

    final sectors = widget.storage.sectors;
    final glasses = widget.storage.glassTypes;
    final defaultBrownGlass = widget.storage.defaultBaselineBrownGlass;
    final ex = widget.existingItem;

    if (ex != null) {
      _selectedSector =
          widget.storage.getSectorById(ex.sectorId) ?? sectors.first;
      _selectedCategory = _selectedSector.isSliding ? 'منزلق' : 'مفصلي';
      _unitType = ex.unitType;
      _openType = ex.openType;
      _barType = ex.barType;
      _openDirection = ex.openDirection;
      _sectorColor = ex.sectorColor;
      _sashCount = ex.sashCount;
      _trackCount = ex.trackCount;
      _hasFlyScreen = ex.hasFlyScreen;
      _hasPanda = ex.hasPanda;
      _isCombinedMeterPrice = ex.isCombinedMeterPrice;

      _labelCtrl = TextEditingController(text: ex.label);
      _widthCtrl =
          TextEditingController(text: ex.widthCm.toStringAsFixed(0));
      _heightCtrl =
          TextEditingController(text: ex.heightCm.toStringAsFixed(0));
      _qtyCtrl = TextEditingController(text: '${ex.quantity}');
      _pricePerM2Ctrl = TextEditingController(
          text: ex.sectorPricePerM2.toStringAsFixed(0));
      _customPdfDescCtrl =
          TextEditingController(text: ex.customPdfDescription);

      _hasArch = ex.hasArch;
      _archWidthCtrl =
          TextEditingController(text: ex.archWidthCm.toStringAsFixed(0));
      _archHeightCtrl =
          TextEditingController(text: ex.archHeightCm.toStringAsFixed(0));
      _archPriceCtrl =
          TextEditingController(text: ex.archPriceEgp.toStringAsFixed(0));

      _hasDoorKickplate = ex.hasDoorKickplate;
      _doorKickHeightCtrl = TextEditingController(
          text: ex.doorBottomKickHeightCm.toStringAsFixed(0));
      _hasDoorMiddleMullion = ex.hasDoorMiddleMullion;
      _doorBottomPanelType = ex.doorBottomPanelType;

      _hasLeftFixed = ex.hasLeftFixed;
      _leftFixedWCtrl = TextEditingController(
          text: ex.leftFixedWidthCm.toStringAsFixed(0));
      _leftFixedSplits = ex.leftFixedSplits;

      _hasRightFixed = ex.hasRightFixed;
      _rightFixedWCtrl = TextEditingController(
          text: ex.rightFixedWidthCm.toStringAsFixed(0));
      _rightFixedSplits = ex.rightFixedSplits;

      _hasTopFixed = ex.hasTopFixed;
      _topFixedHCtrl = TextEditingController(
          text: ex.topFixedHeightCm.toStringAsFixed(0));
      _topFixedSplits = ex.topFixedSplits;

      _hasBottomFixed = ex.hasBottomFixed;
      _bottomFixedHCtrl = TextEditingController(
          text: ex.bottomFixedHeightCm.toStringAsFixed(0));
      _bottomFixedSplits = ex.bottomFixedSplits;

      _hasExhaustFan = ex.hasExhaustFan;
      _exhaustFanShape = ex.exhaustFanShape;
      _exhaustFanDiamCtrl = TextEditingController(
          text: ex.exhaustFanDiameterCm.toStringAsFixed(0));
      _exhaustFanPosition =
          _validExhaustPositions.contains(ex.exhaustFanPosition)
              ? ex.exhaustFanPosition
              : 'في الثابت العلوي';
      _exhaustFanPartIndex = ex.exhaustFanPartIndex;

      if (_hasExhaustFan) {
        _ensureFixedPanelEnabledForExhaust(_exhaustFanPosition);
      }

      _hasGlass = ex.hasGlass;
      _isDoubleGlass = ex.isDoubleGlass;
      _selectedGlass1 = glasses.firstWhere(
        (g) => g.id == ex.glass1Id || g.name == ex.glass1Name,
        orElse: () => defaultBrownGlass,
      );
      _selectedGlass2 = glasses.firstWhere(
        (g) => g.id == ex.glass2Id || g.name == ex.glass2Name,
        orElse: () => glasses.firstWhere(
          (g) => g.name.contains('شفاف'),
          orElse: () => defaultBrownGlass,
        ),
      );
      _customGlassTextCtrl = TextEditingController(text: ex.glass1Name);

      _hasGeorgian = ex.hasGeorgianBars;
      _georgianMetersCtrl = TextEditingController(
          text: ex.georgianMetersPerWindow.toStringAsFixed(1));
    } else {
      _unitType = widget.initialUnitType ?? 'شباك';
      _selectedCategory = widget.initialCategory ??
          (_unitType == 'باب' ? 'مفصلي' : 'منزلق');
      if (widget.initialSector != null) {
        _selectedSector = widget.initialSector!;
        _selectedCategory = _selectedSector.isSliding ? 'منزلق' : 'مفصلي';
      } else {
        final matching = sectors.where((s) {
          final catMatch =
              _selectedCategory == 'منزلق' ? s.isSliding : s.isHinged;
          final grpMatch = widget.initialCompanyGroup == null ||
              s.companyGroup == widget.initialCompanyGroup;
          return catMatch && grpMatch;
        }).toList();
        _selectedSector =
            matching.isNotEmpty ? matching.first : sectors.first;
      }

      _openType = _selectedCategory == 'منزلق' ? 'جرار' : 'مفصلي';
      _sashCount = _selectedCategory == 'منزلق' ? 2 : 1;
      _hasPanda = false;
      _isCombinedMeterPrice = false;

      _labelCtrl = TextEditingController(text: 'W${widget.nextIndex}');
      _widthCtrl =
          TextEditingController(text: _unitType == 'باب' ? '100' : '150');
      _heightCtrl =
          TextEditingController(text: _unitType == 'باب' ? '215' : '120');
      _qtyCtrl = TextEditingController(text: '1');
      _pricePerM2Ctrl = TextEditingController(
          text: _selectedSector.pricePerSquareMeter.toStringAsFixed(0));
      _customPdfDescCtrl = TextEditingController(text: '');

      _hasArch = false;
      _archWidthCtrl =
          TextEditingController(text: _unitType == 'باب' ? '100' : '150');
      _archHeightCtrl = TextEditingController(text: '25');
      _archPriceCtrl = TextEditingController(
          text: widget.storage.pricingSettings.defaultArchPrice
              .toStringAsFixed(0));

      _hasDoorKickplate = true;
      _doorKickHeightCtrl = TextEditingController(text: '75');
      _hasDoorMiddleMullion = true;
      _doorBottomPanelType = 'حشو فايبر / شرائح ألومنيوم';

      _leftFixedWCtrl = TextEditingController(text: '40');
      _rightFixedWCtrl = TextEditingController(text: '40');
      _topFixedHCtrl = TextEditingController(text: '40');
      _bottomFixedHCtrl = TextEditingController(text: '40');
      _exhaustFanDiamCtrl = TextEditingController(text: '25');

      // الافتراضي الأساسي دائماً هو "الزجاج العاكس البني"
      _selectedGlass1 = defaultBrownGlass;
      _selectedGlass2 = glasses.firstWhere(
        (g) => g.name.contains('شفاف'),
        orElse: () => defaultBrownGlass,
      );
      _isDoubleGlass = false;
      _customGlassTextCtrl =
          TextEditingController(text: 'سنجل\n${_selectedGlass1.cleanSingleName}');
      _georgianMetersCtrl = TextEditingController(text: '3.0');
    }
  }

  @override
  void dispose() {
    _optionsTabController.dispose();
    _labelCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _qtyCtrl.dispose();
    _pricePerM2Ctrl.dispose();
    _customPdfDescCtrl.dispose();
    _archWidthCtrl.dispose();
    _archHeightCtrl.dispose();
    _archPriceCtrl.dispose();
    _doorKickHeightCtrl.dispose();
    _leftFixedWCtrl.dispose();
    _rightFixedWCtrl.dispose();
    _topFixedHCtrl.dispose();
    _bottomFixedHCtrl.dispose();
    _exhaustFanDiamCtrl.dispose();
    _customGlassTextCtrl.dispose();
    _georgianMetersCtrl.dispose();
    super.dispose();
  }

  void _ensureFixedPanelEnabledForExhaust(String pos) {
    if (pos.contains('العلوي')) {
      _hasTopFixed = true;
    } else if (pos.contains('السفلي')) {
      _hasBottomFixed = true;
    } else if (pos.contains('اليمين')) {
      _hasRightFixed = true;
    } else if (pos.contains('الشمال')) {
      _hasLeftFixed = true;
    }
  }

  int _activeExhaustFixedSplits() {
    if (_exhaustFanPosition.contains('العلوي')) return _topFixedSplits;
    if (_exhaustFanPosition.contains('السفلي')) return _bottomFixedSplits;
    if (_exhaustFanPosition.contains('اليمين')) return _rightFixedSplits;
    if (_exhaustFanPosition.contains('الشمال')) return _leftFixedSplits;
    return 1;
  }

  void _updateAutoGlassSummaryText() {
    if (!_hasGlass) {
      _customGlassTextCtrl.text = 'بدون زجاج';
      return;
    }
    if (_isDoubleGlass) {
      _customGlassTextCtrl.text =
          'دبل\n${_selectedGlass1.cleanSingleName}\nعلى ${_selectedGlass2.cleanSingleName}';
    } else {
      _customGlassTextCtrl.text =
          'سنجل\n${_selectedGlass1.cleanSingleName}';
    }
  }

  void _switchCategory(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      if (newCat == 'منزلق') {
        _openType = 'جرار';
        _hasPanda = false;
        if (_sashCount < 2) _sashCount = 2;
      } else {
        if (_openType == 'جرار') _openType = 'مفصلي';
      }
      final matching = widget.storage.sectors.where((s) {
        final sameGroup = s.companyGroup == _selectedSector.companyGroup;
        final catMatch = newCat == 'منزلق' ? s.isSliding : s.isHinged;
        return sameGroup && catMatch;
      }).toList();
      if (matching.isNotEmpty) {
        _selectedSector = matching.first;
        _pricePerM2Ctrl.text =
            _selectedSector.pricePerSquareMeter.toStringAsFixed(0);
      } else {
        final anyCat = widget.storage.sectors
            .where((s) => newCat == 'منزلق' ? s.isSliding : s.isHinged)
            .toList();
        if (anyCat.isNotEmpty) {
          _selectedSector = anyCat.first;
          _pricePerM2Ctrl.text =
              _selectedSector.pricePerSquareMeter.toStringAsFixed(0);
        }
      }
    });
  }

  ClientWindowItem _buildCurrentWindowItem() {
    final double w = double.tryParse(_widthCtrl.text.trim()) ?? 150.0;
    final double h = double.tryParse(_heightCtrl.text.trim()) ?? 120.0;
    final int q = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final double priceM2 = double.tryParse(_pricePerM2Ctrl.text.trim()) ??
        _selectedSector.pricePerSquareMeter;

    final int maxFanPart = math.max<int>(0, _activeExhaustFixedSplits() - 1);
    final int safeFanPartIdx = _exhaustFanPartIndex.clamp(0, maxFanPart).toInt();
    final double baselineBrownPrice =
        widget.storage.defaultBaselineBrownGlass.pricePerSquareMeter;

    return ClientWindowItem(
      id: widget.existingItem?.id ??
          'win_${DateTime.now().millisecondsSinceEpoch}',
      label: _labelCtrl.text.trim().isEmpty
          ? 'W${widget.nextIndex}'
          : _labelCtrl.text.trim(),
      unitType: _unitType,
      openType: _openType,
      barType: _barType,
      openDirection: _openDirection,
      sectorId: _selectedSector.id,
      sectorName: _selectedSector.shortPdfName,
      customPdfDescription: _customPdfDescCtrl.text.trim(),
      sectorPricePerM2: priceM2,
      isCombinedMeterPrice: _isCombinedMeterPrice,
      sectorColor: _sectorColor,
      widthCm: w,
      heightCm: h,
      quantity: q > 0 ? q : 1,
      sashCount: _sashCount,
      trackCount: _trackCount,
      hasFlyScreen: _hasFlyScreen,
      hasPanda: _hasPanda &&
          (_openType.contains('مفصلي') || _openType.contains('قلاب')),
      hasDoorKickplate: _hasDoorKickplate,
      doorBottomKickHeightCm:
          double.tryParse(_doorKickHeightCtrl.text.trim()) ?? 75.0,
      hasDoorMiddleMullion: _hasDoorMiddleMullion,
      doorBottomPanelType: _doorBottomPanelType,
      hasArch: _hasArch,
      archWidthCm: double.tryParse(_archWidthCtrl.text.trim()) ?? w,
      archHeightCm: double.tryParse(_archHeightCtrl.text.trim()) ?? 25.0,
      archPriceEgp: double.tryParse(_archPriceCtrl.text.trim()) ?? 600.0,
      hasTopFixed: _hasTopFixed,
      topFixedHeightCm:
          double.tryParse(_topFixedHCtrl.text.trim()) ?? 40.0,
      topFixedSplits: _topFixedSplits,
      hasBottomFixed: _hasBottomFixed,
      bottomFixedHeightCm:
          double.tryParse(_bottomFixedHCtrl.text.trim()) ?? 40.0,
      bottomFixedSplits: _bottomFixedSplits,
      hasRightFixed: _hasRightFixed,
      rightFixedWidthCm:
          double.tryParse(_rightFixedWCtrl.text.trim()) ?? 40.0,
      rightFixedSplits: _rightFixedSplits,
      hasLeftFixed: _hasLeftFixed,
      leftFixedWidthCm:
          double.tryParse(_leftFixedWCtrl.text.trim()) ?? 40.0,
      leftFixedSplits: _leftFixedSplits,
      hasExhaustFan: _hasExhaustFan,
      exhaustFanShape: _exhaustFanShape,
      exhaustFanDiameterCm:
          double.tryParse(_exhaustFanDiamCtrl.text.trim()) ?? 25.0,
      exhaustFanPosition: _exhaustFanPosition,
      exhaustFanPartIndex: safeFanPartIdx,
      hasGlass: _hasGlass,
      isDoubleGlass: _isDoubleGlass,
      glass1Id: _selectedGlass1.id,
      glass1Name: _customGlassTextCtrl.text.trim().isNotEmpty
          ? _customGlassTextCtrl.text.trim()
          : _selectedGlass1.name,
      glass1PricePerM2: _selectedGlass1.pricePerSquareMeter,
      glass2Id: _selectedGlass2.id,
      glass2Name: _selectedGlass2.name,
      glass2PricePerM2: _selectedGlass2.pricePerSquareMeter,
      baselineGlassPricePerM2: baselineBrownPrice,
      spacerPricePerMeter:
          widget.storage.pricingSettings.doubleSpacerPricePerMeter,
      hasGeorgianBars: _hasGeorgian,
      georgianMetersPerWindow:
          double.tryParse(_georgianMetersCtrl.text.trim()) ?? 0.0,
      georgianPricePerMeter:
          widget.storage.pricingSettings.georgianBarPricePerMeter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final curItem = _buildCurrentWindowItem();
    final minOneM2 =
        widget.storage.pricingSettings.enforceMinimumOneSquareMeter;
    final singleArea = curItem.displaySingleAreaM2(minOneM2: minOneM2);
    final effectiveMeter = curItem.effectiveMeterPrice(_selectedSector);
    final totalCost =
        curItem.calculateTotalCost(_selectedSector, minOneM2: minOneM2);
    final bool fanOptimal = curItem.isExhaustFanSizeOptimal(
        fixedDeductCm: _selectedSector.fixedGlassDeductCm);

    return Scaffold(
      resizeToAvoidBottomInset: false, // واجهة المعاينة ثابتة دائماً ولا تتحرك أو تختفي!
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B110A),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            if (_selectedSector.companyLogoAsset != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    _selectedSector.companyLogoAsset!,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                _selectedSector.name,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: SegmentedButton<String>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 6)),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFD97706);
                  }
                  return const Color(0xFF334155);
                }),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
              ),
              segments: const [
                ButtonSegment(
                  value: 'منزلق',
                  label: Text('منزلق',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                ButtonSegment(
                  value: 'مفصلي',
                  label: Text('مفصلي',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
              selected: {_selectedCategory},
              onSelectionChanged: (s) => _switchCategory(s.first),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ==================== 1. شاشة المعاينة الحية المثبتة في الأعلى دائماً (Pinned Preview Area) ====================
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              children: [
                Window2DVisualizer(
                  widthCm: curItem.widthCm,
                  heightCm: curItem.heightCm,
                  unitType: curItem.unitType,
                  openType: curItem.openType,
                  sashCount: curItem.sashCount,
                  barType: curItem.barType,
                  openDirection: curItem.openDirection,
                  sectorColor: curItem.sectorColor,
                  hasArch: curItem.hasArch,
                  archWidthCm: curItem.archWidthCm,
                  archHeightCm: curItem.archHeightCm,
                  hasDoorKickplate: curItem.hasDoorKickplate,
                  doorBottomKickHeightCm: curItem.doorBottomKickHeightCm,
                  hasDoorMiddleMullion: curItem.hasDoorMiddleMullion,
                  doorBottomPanelType: curItem.doorBottomPanelType,
                  hasTopFixed: curItem.hasTopFixed,
                  topFixedHeightCm: curItem.topFixedHeightCm,
                  topFixedSplits: curItem.topFixedSplits,
                  hasBottomFixed: curItem.hasBottomFixed,
                  bottomFixedHeightCm: curItem.bottomFixedHeightCm,
                  bottomFixedSplits: curItem.bottomFixedSplits,
                  hasRightFixed: curItem.hasRightFixed,
                  rightFixedWidthCm: curItem.rightFixedWidthCm,
                  rightFixedSplits: curItem.rightFixedSplits,
                  hasLeftFixed: curItem.hasLeftFixed,
                  leftFixedWidthCm: curItem.leftFixedWidthCm,
                  leftFixedSplits: curItem.leftFixedSplits,
                  hasExhaustFan: curItem.hasExhaustFan,
                  exhaustFanShape: curItem.exhaustFanShape,
                  exhaustFanDiameterCm: curItem.exhaustFanDiameterCm,
                  exhaustFanPosition: curItem.exhaustFanPosition,
                  exhaustFanPartIndex: curItem.exhaustFanPartIndex,
                  isExhaustFanFitOptimal: fanOptimal,
                  hasGlass: curItem.hasGlass,
                  isDoubleGlass: curItem.isDoubleGlass,
                  hasGeorgian: curItem.hasGeorgianBars,
                  hasFlyScreen: curItem.hasFlyScreen,
                  hasPanda: curItem.hasPanda,
                  height: 178,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المتحرك: ${curItem.netOperableWidthCm.toStringAsFixed(0)}×${curItem.netOperableHeightCm.toStringAsFixed(0)} سم',
                      style: const TextStyle(
                        color: Color(0xFFBAE6FD),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'المتر: ${effectiveMeter.toStringAsFixed(0)} ج (${singleArea.toStringAsFixed(2)} م²)${curItem.hasArch ? " + دوران ${curItem.archPriceEgp.toStringAsFixed(0)}ج" : ""}',
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'الإجمالي: ${totalCost.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==================== 2. تبويبات الخيارات السفلية المفصولة عن المعاينة ====================
          Container(
            color: const Color(0xFF1E293B),
            child: TabBar(
              controller: _optionsTabController,
              isScrollable: false,
              labelColor: const Color(0xFFF59E0B),
              unselectedLabelColor: Colors.white70,
              indicatorColor: const Color(0xFFF59E0B),
              labelStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '1. المقاس والدوران'),
                Tab(text: '2. الثوابت وإتش'),
                Tab(text: '3. القطاع والزجاج'),
                Tab(text: '4. الشفاط والجورجيا'),
              ],
            ),
          ),

          // ==================== 3. القائمة السفلية القابلة للتمرير (Scrollable) دون تحرك المعاينة ====================
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom * 0.45
                    : 0,
              ),
              child: TabBarView(
                controller: _optionsTabController,
                children: [
                  _buildDimensionsAndSashesTab(curItem),
                  _buildFixedPanelsTab(curItem),
                  _buildSectorAndGlassTab(curItem),
                  _buildExhaustAndExtrasTab(curItem),
                ],
              ),
            ),
          ),

          // ==================== 4. زر الحفظ والإضافة ====================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context, _buildCurrentWindowItem());
                  },
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: Text(
                    widget.existingItem == null
                        ? 'إضافة ${_unitType} بنفس شكله للطلبية وعرض السعر'
                        : 'حفظ التعديلات على ${_unitType}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// التبويب الأول: أبعاد الشباك، أبعاد وسعر الدوران العلوي، الأبواب، عدد الضلف، والباندا للمفصلي
  Widget _buildDimensionsAndSashesTab(ClientWindowItem curItem) {
    final bool isHingedMode = _selectedCategory == 'مفصلي' ||
        _openType == 'مفصلي' ||
        _openType == 'قلاب';
    final double baseSectorMeter =
        double.tryParse(_pricePerM2Ctrl.text.trim()) ??
            _selectedSector.pricePerSquareMeter;

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        // صف المقاسات الأساسي (العرض، الطول، العدد، رمز البند)
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _widthCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) {
                  setState(() {
                    if (!_hasArch || _archWidthCtrl.text.trim().isEmpty) {
                      _archWidthCtrl.text = val;
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'العرض (سم)',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _heightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'الطول / الارتفاع (سم)',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'العدد',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _labelCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'الرمز',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ==================== خيارات الدوران العلوي (تحت أبعاد الشباك مباشرة كما طلب المستخدم) ====================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hasArch ? const Color(0xFFFEF3C7) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  _hasArch ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
              width: _hasArch ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFFD97706),
                title: const Text(
                  'إضافة دوران علوي للشباك (قوس) مع تسعيره ورسمه',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
                subtitle: const Text(
                  'يُضاف سعر الدوران لسعر الشباك في عرض السعر ويُطبع مقاسه فقط في الطلبية للإبلاغ دون تضليع',
                  style: TextStyle(fontSize: 10.5),
                ),
                value: _hasArch,
                onChanged: (v) {
                  setState(() {
                    _hasArch = v;
                    if (v) {
                      _archWidthCtrl.text = _widthCtrl.text;
                    }
                  });
                },
              ),
              if (_hasArch) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _archWidthCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'عرض الدوران / الوتر (سم)',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _archHeightCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'ارتفاع أقصى نقطة بالمنتصف (سم)',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _archPriceCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'سعر الدوران (ج.م)',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFB45309)),
                  ),
                  child: Text(
                    'مقاس الدوران للإبلاغ: الوتر ${curItem.archWidthCm.toStringAsFixed(0)} سم × الارتفاع بالمنتصف ${curItem.archHeightCm.toStringAsFixed(0)} سم • نصف القطر R=${curItem.archRadiusCm.toStringAsFixed(1)} سم • القوس الصافي=${curItem.archNetArcLengthCm.toStringAsFixed(1)} سم (+20سم ركوب درفلة)',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // اختيار طريقة الفتح (جرار منزلق | مفصلي | قلاب | ثابت) + نوع الوحدة (شباك / باب)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final t in ['جرار', 'مفصلي', 'قلاب', 'ثابت'])
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(t == 'جرار' ? 'جرار' : t),
                      selected: _openType == t,
                      selectedColor: const Color(0xFF31869B),
                      labelStyle: TextStyle(
                        color: _openType == t ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                      onSelected: (_) {
                        if (t == 'جرار') {
                          _switchCategory('منزلق');
                        } else if (t == 'مفصلي' || t == 'قلاب') {
                          _switchCategory('مفصلي');
                          setState(() {
                            _openType = t;
                            if (t == 'قلاب') _sashCount = 1;
                          });
                        } else {
                          setState(() {
                            _openType = t;
                            _hasPanda = false;
                          });
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _unitType,
                decoration: const InputDecoration(
                  labelText: 'شباك أم باب',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'شباك', child: Text('شباك ألوميتال')),
                  DropdownMenuItem(value: 'باب', child: Text('باب ألوميتال')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _unitType = v;
                      if (v == 'باب') {
                        _hasPanda = false;
                        if (_heightCtrl.text == '120') _heightCtrl.text = '215';
                        if (_widthCtrl.text == '150') _widthCtrl.text = '100';
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // عدد الضلف (1، 2، 3، 4) + البار واتجاه الفتح
        Row(
          children: [
            const Text('عدد الضلف: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            for (final sc in [1, 2, 3, 4])
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('$sc'),
                  selected: _sashCount == sc,
                  selectedColor: const Color(0xFFD97706),
                  labelStyle: TextStyle(
                    color: _sashCount == sc ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _sashCount = sc),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _barType,
                decoration: const InputDecoration(
                  labelText: 'البار (الحلق)',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ببار', child: Text('حلق ببار')),
                  DropdownMenuItem(
                      value: 'بدون بار', child: Text('حلق بدون بار')),
                  DropdownMenuItem(
                      value: 'بار مقلوب', child: Text('بار مقلوب / تجميع')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _barType = v);
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _openDirection,
                decoration: const InputDecoration(
                  labelText: 'اتجاه الفتح',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'يمين للداخل', child: Text('يمين للداخل')),
                  DropdownMenuItem(
                      value: 'شمال للداخل', child: Text('شمال للداخل')),
                  DropdownMenuItem(
                      value: 'يمين للخارج', child: Text('يمين للخارج')),
                  DropdownMenuItem(
                      value: 'شمال للخارج', child: Text('شمال للخارج')),
                  DropdownMenuItem(
                      value: 'قلاب لأعلى', child: Text('قلاب لأعلى')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _openDirection = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('إضافة سلك مانع للحشرات (ضلفة سلك)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          value: _hasFlyScreen,
          onChanged: (v) => setState(() => _hasFlyScreen = v),
        ),

        // ==================== قسم الأبواب الخاص وتخصيماتها وأشكالها ====================
        if (_unitType == 'باب')
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF16A34A), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🚪 إعدادات وتخصيمات قسم الأبواب (كعب الباب وعارضة الوسط والحشو):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: Color(0xFF14532D),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إضافة كعب باب سفلي عريض (سوكلي)',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _hasDoorKickplate,
                  onChanged: (v) => setState(() => _hasDoorKickplate = v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إضافة عارضة / سؤاس وسط الباب',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _hasDoorMiddleMullion,
                  onChanged: (v) => setState(() => _hasDoorMiddleMullion = v),
                ),
                if (_hasDoorMiddleMullion)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _doorKickHeightCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'ارتفاع الجزء السفلي (سم)',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _doorBottomPanelType,
                          decoration: const InputDecoration(
                            labelText: 'نوع الجزء السفلي للباب',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'حشو فايبر / شرائح ألومنيوم',
                              child: Text('حشو فايبر / شرائح ألومنيوم'),
                            ),
                            DropdownMenuItem(
                              value: 'زجاج',
                              child: Text('زجاج مثل الجزء العلوي'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _doorBottomPanelType = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

        // ==================== قواعد درف الباندا (في القطاعات المفصلي) ====================
        if (isHingedMode && _unitType == 'شباك')
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hasPanda ? const Color(0xFFFEF3C7) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hasPanda
                    ? const Color(0xFFD97706)
                    : const Color(0xFFCBD5E1),
                width: _hasPanda ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFFD97706),
                  title: const Text(
                    'تفعيل نظام درف الباندا (Panda System) للمفصلي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF7F1D1D),
                    ),
                  ),
                  subtitle: Text(
                    _hasPanda
                        ? 'مُفعّل: درف خلفية للسلك + درف أمامية للزجاج (الزجاج يُحسب على الدرف الأمامية فقط) • سعر المتر الأساسي × 1.5 = ${(baseSectorMeter * 1.5).toStringAsFixed(0)} ج.م/م²'
                        : 'درفتين خلفيتين للسلك + درفتين أماميتين للزجاج، وتسعير المتر بـ 1.5 (مرة ونصف)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          _hasPanda ? FontWeight.bold : FontWeight.normal,
                      color: _hasPanda
                          ? const Color(0xFFB45309)
                          : const Color(0xFF475569),
                    ),
                  ),
                  value: _hasPanda,
                  onChanged: (v) {
                    setState(() {
                      _hasPanda = v;
                      if (v) {
                        _hasFlyScreen = true;
                        if (_sashCount < 2) _sashCount = 2;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// التبويب الثاني: الثوابت وأماكنها (شمال، يمين، فوق، تحت) + قاعدة (جرار + ثابت علوي + قطاع إتش + بار منفصل)
  Widget _buildFixedPanelsTab(ClientWindowItem curItem) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        if (curItem.usesSlidingWithTopFixedHConnector)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD97706), width: 1.4),
            ),
            child: const Row(
              children: [
                Icon(Icons.precision_manufacturing,
                    color: Color(0xFFB45309), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'نظام التركيبة المشتركة مفعّل تلقائياً: يتم تصنيع الشباك الجرار والثابت العلوي كقطعتين بدون بار مدمج، ويربط بينهما قطاع "إتش" (H-Profile)، ويلتف حولهما بار منفصل حوالين داير!',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7F1D1D),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 1. ثابت علوي (فوق)
        _buildFixedPanelControlCard(
          title: '⬆️ ثابت علوي (فوق الشباك — مع قطاع إتش للجرار)',
          enabled: _hasTopFixed,
          onToggle: (v) => setState(() => _hasTopFixed = v),
          sizeCtrl: _topFixedHCtrl,
          sizeLabel: 'ارتفاع الثابت العلوي (سم)',
          splits: _topFixedSplits,
          onSplitsChanged: (s) => setState(() => _topFixedSplits = s),
        ),

        // 2. ثابت سفلي (تحت)
        _buildFixedPanelControlCard(
          title: '⬇️ ثابت سفلي (جلسة تحت الشباك)',
          enabled: _hasBottomFixed,
          onToggle: (v) => setState(() => _hasBottomFixed = v),
          sizeCtrl: _bottomFixedHCtrl,
          sizeLabel: 'ارتفاع الثابت السفلي (سم)',
          splits: _bottomFixedSplits,
          onSplitsChanged: (s) => setState(() => _bottomFixedSplits = s),
        ),

        // 3. ثابت شمال (يسار)
        _buildFixedPanelControlCard(
          title: '⬅️ ثابت شمال (يسار الشباك)',
          enabled: _hasLeftFixed,
          onToggle: (v) => setState(() => _hasLeftFixed = v),
          sizeCtrl: _leftFixedWCtrl,
          sizeLabel: 'عرض الثابت الشمال (سم)',
          splits: _leftFixedSplits,
          onSplitsChanged: (s) => setState(() => _leftFixedSplits = s),
        ),

        // 4. ثابت يمين
        _buildFixedPanelControlCard(
          title: '➡️ ثابت يمين الشباك',
          enabled: _hasRightFixed,
          onToggle: (v) => setState(() => _hasRightFixed = v),
          sizeCtrl: _rightFixedWCtrl,
          sizeLabel: 'عرض الثابت اليمين (سم)',
          splits: _rightFixedSplits,
          onSplitsChanged: (s) => setState(() => _rightFixedSplits = s),
        ),
      ],
    );
  }

  Widget _buildFixedPanelControlCard({
    required String title,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required TextEditingController sizeCtrl,
    required String sizeLabel,
    required int splits,
    required ValueChanged<int> onSplitsChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: enabled ? const Color(0xFFFEF3C7) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: enabled ? const Color(0xFFD97706) : Colors.grey.shade300,
          width: enabled ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Switch(
                  value: enabled,
                  activeColor: const Color(0xFFD97706),
                  onChanged: onToggle,
                ),
              ],
            ),
            if (enabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: sizeCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: sizeLabel,
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: splits,
                        decoration: const InputDecoration(
                          labelText: 'تقسيم الثابت',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 1, child: Text('قطعة واحدة')),
                          DropdownMenuItem(value: 2, child: Text('مقسوم 2')),
                          DropdownMenuItem(value: 3, child: Text('مقسوم 3')),
                          DropdownMenuItem(value: 4, child: Text('مقسوم 4')),
                        ],
                        onChanged: (v) {
                          if (v != null) onSplitsChanged(v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// التبويب الثالث: اختيار القطاع، اللون، وقواعد تسعير الزجاج (العاكس البني كـ Default + قاعدة الترقية وحماية السعر الأدنى)
  Widget _buildSectorAndGlassTab(ClientWindowItem curItem) {
    final allSectors = widget.storage.sectors;
    final glasses = widget.storage.glassTypes;
    final double baselineBrownPrice =
        widget.storage.defaultBaselineBrownGlass.pricePerSquareMeter;
    final double spacerPrice =
        widget.storage.pricingSettings.doubleSpacerPricePerMeter;
    final double upgradeDiff = curItem.glassUpgradeDiffPerM2();

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        // اختيار القطاع مع عرض صورة المقطع ورابط الكتالوج
        Row(
          children: [
            SvgProfileWidget(
              assetPath: _selectedSector.primaryProfileSvg,
              width: 46,
              height: 46,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedSector.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'القطاع المختار',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: allSectors
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '[${s.companyGroup}] ${s.name}',
                            style: const TextStyle(fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    final found = widget.storage.getSectorById(val);
                    if (found != null) {
                      setState(() {
                        _selectedSector = found;
                        _selectedCategory =
                            found.isSliding ? 'منزلق' : 'مفصلي';
                        if (found.isSliding) {
                          _openType = 'جرار';
                          _hasPanda = false;
                        } else if (_openType == 'جرار') {
                          _openType = 'مفصلي';
                        }
                        _pricePerM2Ctrl.text =
                            found.pricePerSquareMeter.toStringAsFixed(0);
                      });
                    }
                  }
                },
              ),
            ),
            if (_selectedSector.catalogUrl.isNotEmpty)
              IconButton(
                tooltip: 'فتح كتالوج القطاع',
                icon: const Icon(Icons.menu_book, color: Color(0xFFD97706)),
                onPressed: () {
                  NativeFileService.openExternalUrl(_selectedSector.catalogUrl);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),

        // لون القطاع + السعر الافتراضي للمتر المسطح (بالعاكس البني)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _sectorColor,
                decoration: const InputDecoration(
                  labelText: 'لون القطاع',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'بيج', child: Text('بيج')),
                  DropdownMenuItem(value: 'أسود', child: Text('أسود')),
                  DropdownMenuItem(value: 'أبيض', child: Text('أبيض')),
                  DropdownMenuItem(value: 'رمادي', child: Text('رمادي')),
                  DropdownMenuItem(value: 'خشابي', child: Text('خشابي')),
                  DropdownMenuItem(value: 'شامبين', child: Text('شامبين')),
                  DropdownMenuItem(value: 'فضي', child: Text('فضي')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _sectorColor = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _pricePerM2Ctrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'سعر المتر بالعاكس البني (ج.م)',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ==================== اختيار نظام الزجاج (Default Baseline: العاكس البني) ====================
        const Text(
          'نظام الزجاج (السعر الأساسي محسوب دائماً على الزجاج العاكس البني):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const SizedBox(
                  width: double.infinity,
                  child: Text('زجاج سنجل',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
                selected: _hasGlass && !_isDoubleGlass,
                selectedColor: const Color(0xFF31869B),
                labelStyle: TextStyle(
                  color: (_hasGlass && !_isDoubleGlass)
                      ? Colors.white
                      : Colors.black87,
                ),
                onSelected: (_) {
                  setState(() {
                    _hasGlass = true;
                    _isDoubleGlass = false;
                    _isCombinedMeterPrice = false;
                    _updateAutoGlassSummaryText();
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ChoiceChip(
                label: const SizedBox(
                  width: double.infinity,
                  child: Text('زجاج دابل + سبيسر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
                selected: _hasGlass && _isDoubleGlass,
                selectedColor: const Color(0xFFD97706),
                labelStyle: TextStyle(
                  color: (_hasGlass && _isDoubleGlass)
                      ? Colors.white
                      : Colors.black87,
                ),
                onSelected: (_) {
                  setState(() {
                    _hasGlass = true;
                    _isDoubleGlass = true;
                    _isCombinedMeterPrice = false;
                    _updateAutoGlassSummaryText();
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ChoiceChip(
                label: const SizedBox(
                  width: double.infinity,
                  child: Text('بدون زجاج',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
                selected: !_hasGlass,
                selectedColor: const Color(0xFF475569),
                labelStyle: TextStyle(
                  color: !_hasGlass ? Colors.white : Colors.black87,
                ),
                onSelected: (_) {
                  setState(() {
                    _hasGlass = false;
                    _updateAutoGlassSummaryText();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_hasGlass && !_isDoubleGlass) ...[
          DropdownButtonFormField<String>(
            value: _selectedGlass1.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'نوع الزجاج السنجل (الافتراضي: عاكس بني)',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            items: glasses
                .map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(
                        '${g.name.replaceAll('\n', ' ')} (${g.pricePerSquareMeter.toStringAsFixed(0)} ج.م/م²)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                final g = glasses.firstWhere((e) => e.id == v);
                setState(() {
                  _selectedGlass1 = g;
                  _isCombinedMeterPrice = false;
                  _updateAutoGlassSummaryText();
                });
              }
            },
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: upgradeDiff > 0
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: upgradeDiff > 0
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A),
              ),
            ),
            child: Text(
              upgradeDiff > 0
                  ? '⬆️ قاعدة ترقية الزجاج: هذا الزجاج أعلى من العاكس البني الافتراضي (${baselineBrownPrice.toStringAsFixed(0)}ج)، تمت إضافة فارق الترقية (+${upgradeDiff.toStringAsFixed(0)} ج.م/م²) فوق سعر المتر الأساسي.'
                  : '🛡️ قاعدة حماية السعر الأدنى: سعر المتر محسوب على الديفولت الطبيعي (العاكس البني ${baselineBrownPrice.toStringAsFixed(0)} ج.م) ولا يقل سعر المتر عند اختيار زجاج أرخص (+0 ج.م خصم).',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ] else if (_hasGlass && _isDoubleGlass) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD97706), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختيار طبقتي الزجاج الدابل + إضافة سعر السبيسر فوق سعر المتر:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGlass1.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '1. الطبقة الأولى للزجاج الدابل (الخارجي)',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  items: glasses
                      .map((g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              '${g.cleanSingleName} (${g.pricePerSquareMeter.toStringAsFixed(0)} ج.م/م²)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      final g = glasses.firstWhere((e) => e.id == v);
                      setState(() {
                        _selectedGlass1 = g;
                        _isCombinedMeterPrice = false;
                        _updateAutoGlassSummaryText();
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGlass2.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '2. الطبقة الثانية للزجاج الدابل (الداخلي)',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  items: glasses
                      .map((g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              '${g.cleanSingleName} (${g.pricePerSquareMeter.toStringAsFixed(0)} ج.م/م²)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      final g = glasses.firstWhere((e) => e.id == v);
                      setState(() {
                        _selectedGlass2 = g;
                        _isCombinedMeterPrice = false;
                        _updateAutoGlassSummaryText();
                      });
                    }
                  },
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFB45309)),
                  ),
                  child: Text(
                    'إضافة الدابل والسبيسر فوق سعر المتر الأساسي: فرق الطبقة الأولى (+${math.max(0.0, _selectedGlass1.pricePerSquareMeter - baselineBrownPrice).toStringAsFixed(0)}ج) + الطبقة الثانية (+${_selectedGlass2.pricePerSquareMeter.toStringAsFixed(0)}ج) + السبيسر (+${spacerPrice.toStringAsFixed(0)}ج) = +${upgradeDiff.toStringAsFixed(0)} ج.م/م²',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),

        // نص نوع الزجاج والتوصيف المطبوع في جدول عرض السعر PDF
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customGlassTextCtrl,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'تسمية الزجاج في الـ PDF',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _customPdfDescCtrl,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'توصيف البند في الـ PDF (اختياري)',
                  hintText: 'تلقائي حسب الفتحة والقطاع',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// التبويب الرابع: الشفاط (يركب في الثوابت فقط + مؤشر المقاس الأخضر الذكي) والجورجيا
  Widget _buildExhaustAndExtrasTab(ClientWindowItem curItem) {
    final int activeSplits = _activeExhaustFixedSplits();
    if (_exhaustFanPartIndex >= activeSplits) {
      _exhaustFanPartIndex = 0;
    }
    final bool fanOptimal = curItem.isExhaustFanSizeOptimal(
        fixedDeductCm: _selectedSector.fixedGlassDeductCm);
    final double maxAllowedFanCm = curItem.maxAllowedExhaustFanDiameterCm(
        fixedDeductCm: _selectedSector.fixedGlassDeductCm);

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: _hasExhaustFan
                  ? (fanOptimal
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626))
                  : Colors.grey.shade300,
              width: _hasExhaustFan ? 1.8 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: Image.asset(
                    'assets/images/windows/suction.png',
                    width: 34,
                    height: 34,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.cyclone, color: Colors.green),
                  ),
                  title: const Text(
                    'إضافة فتحة شفاط (يوضع داخل الثوابت فقط)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'يُمنع وضعه داخل الدرف المتحركة، ويضيء الشفاط باللون الأخضر عندما يكون مقاسه مناسباً للثابت المحدد',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _hasExhaustFan,
                  onChanged: (v) {
                    setState(() {
                      _hasExhaustFan = v;
                      if (v) {
                        _ensureFixedPanelEnabledForExhaust(_exhaustFanPosition);
                      }
                    });
                  },
                ),
                if (_hasExhaustFan) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _exhaustFanDiamCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'مقاس الشفاط (سم)',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _exhaustFanPosition,
                          decoration: const InputDecoration(
                            labelText: 'مكان الثابت للشفاط',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'في الثابت العلوي',
                              child: Text('في الثابت العلوي (فوق)'),
                            ),
                            DropdownMenuItem(
                              value: 'في الثابت السفلي',
                              child: Text('في الثابت السفلي (تحت)'),
                            ),
                            DropdownMenuItem(
                              value: 'في الثابت اليمين',
                              child: Text('في الثابت اليمين'),
                            ),
                            DropdownMenuItem(
                              value: 'في الثابت الشمال',
                              child: Text('في الثابت الشمال'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _exhaustFanPosition = v;
                                _exhaustFanPartIndex = 0;
                                _ensureFixedPanelEnabledForExhaust(v);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (activeSplits > 1) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _exhaustFanPartIndex,
                      decoration: const InputDecoration(
                        labelText:
                            'اختر الجزء الواحد من الثابت المقسم لوضع الشفاط فيه',
                        isDense: true,
                        filled: true,
                        fillColor: Color(0xFFFEF3C7),
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        activeSplits,
                        (idx) => DropdownMenuItem(
                          value: idx,
                          child: Text(
                            'وضع الشفاط في الجزء رقم ${idx + 1} فقط (من أصل $activeSplits أجزاء)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _exhaustFanPartIndex = val);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  // مؤشر المقاس الأخضر الذكي للشفاط!
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: fanOptimal
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: fanOptimal
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          fanOptimal ? Icons.verified : Icons.error_outline,
                          color: fanOptimal
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fanOptimal
                                ? '✅ مؤشر المقاس الأخضر: مقاس الشفاط (${curItem.exhaustFanDiameterCm.toStringAsFixed(0)} سم) مضبوط ومناسب تماماً لمقاس الثابت المحدد (صافي فتحة الثابت المتاحة: ${maxAllowedFanCm.toStringAsFixed(1)} سم)'
                                : '⚠️ تنبيه المقاس: مقاس الشفاط (${curItem.exhaustFanDiameterCm.toStringAsFixed(0)} سم) أكبر من صافي فتحة الثابت المتاحة (${maxAllowedFanCm.toStringAsFixed(1)} سم)! يرجى تكبير الثابت أو تقليل مقاس الشفاط.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: fanOptimal
                                  ? const Color(0xFF14532D)
                                  : const Color(0xFF7F1D1D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                      'إضافة شبكة أعواد جورجيا جمالية بين الزجاج',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    'تُحسب تكلفة الجورجيا (${widget.storage.pricingSettings.georgianBarPricePerMeter.toStringAsFixed(0)} ج.م/متر) وتُضاف فوق السعر الأساسي',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: _hasGeorgian,
                  onChanged: (v) => setState(() => _hasGeorgian = v),
                ),
                if (_hasGeorgian)
                  TextField(
                    controller: _georgianMetersCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'عدد أمتار الجورجيا للشباك الواحد',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
