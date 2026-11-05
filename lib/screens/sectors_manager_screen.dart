import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/workshop_models.dart';
import '../services/native_file_service.dart';
import '../services/workshop_storage.dart';
import '../widgets/svg_profile_widget.dart';

class SectorsManagerScreen extends StatefulWidget {
  final WorkshopStorage storage;
  const SectorsManagerScreen({super.key, required this.storage});

  @override
  State<SectorsManagerScreen> createState() => _SectorsManagerScreenState();
}

class _SectorsManagerScreenState extends State<SectorsManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedGroupFilter = 'الكل';
  String _selectedCatFilter = 'الكل'; // الكل | منزلق | مفصلي

  // حاسبة الدورانات والأقواس (كما في المشروع المماثل)
  final _chordCtrl = TextEditingController(text: '120'); // الوتر
  final _sagittaCtrl = TextEditingController(text: '30'); // العمق / السهم

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chordCtrl.dispose();
    _sagittaCtrl.dispose();
    super.dispose();
  }

  void _openSectorEditor({SectorProfile? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SectorEditorPage(
          storage: widget.storage,
          existingSector: existing,
        ),
      ),
    );
  }

  void _showSectorCatalogModal(SectorProfile sec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.80,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (sec.companyLogoAsset != null)
                  Image.asset(sec.companyLogoAsset!, width: 44, height: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كتالوج ومقاطع قطاع: ${sec.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'الشركة: ${sec.companyGroup} • النظام: ${sec.category}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                if (sec.catalogUrl.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      NativeFileService.openExternalUrl(sec.catalogUrl);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('رابط الكتالوج الخارجي'),
                  ),
              ],
            ),
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: Text(
                'معادلات الزجاج الصافية للقطاع: خصم زجاج الضلفة (${sec.glassWidthDeductCm} سم عرض / ${sec.glassHeightDeductCm} سم ارتفاع) • خصم زجاج الثابت (${sec.fixedGlassDeductCm} سم) • خصم السؤاس (${sec.transomDeductCm} سم)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7F1D1D),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'رسومات مقاطع الألومنيوم وتخصيمات كل جزء في القطاع (كل جزء أمامه شكل مقطعه الصحيح):',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: sec.parts.length,
                itemBuilder: (ctx, i) {
                  final p = sec.parts[i];
                  final sign = p.offsetCm >= 0 ? '+' : '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: SvgProfileWidget(
                        assetPath: p.svgAssetPath ?? sec.primaryProfileSvg,
                        width: 58,
                        height: 58,
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'النوع: ${p.role} • المعادلة: ${p.basisArabicLabel} ($sign${p.offsetCm} سم) • العدد: ${p.quantityPerWindow}${p.multiplyBySashes ? " × عدد الضلف" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E293B),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFF59E0B),
              unselectedLabelColor: Colors.white70,
              indicatorColor: const Color(0xFFF59E0B),
              tabs: const [
                Tab(icon: Icon(Icons.view_module, size: 18), text: 'القطاعات والكتالوجات'),
                Tab(icon: Icon(Icons.palette, size: 18), text: 'كتالوجات الألوان'),
                Tab(icon: Icon(Icons.architecture, size: 18), text: 'حساب الدورانات'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSectorsAndCatalogsTab(),
                _buildColorsCataloguesTab(),
                _buildRadiusCalculatorTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorsAndCatalogsTab() {
    final allSectors = widget.storage.sectors;
    final groups = ['الكل', ...allSectors.map((e) => e.companyGroup).toSet()];

    final filtered = allSectors.where((s) {
      final grpMatch = _selectedGroupFilter == 'الكل' ||
          s.companyGroup == _selectedGroupFilter;
      final catMatch = _selectedCatFilter == 'الكل' ||
          (_selectedCatFilter == 'منزلق' ? s.isSliding : s.isHinged);
      return grpMatch && catMatch;
    }).toList();

    return Column(
      children: [
        // شريط فلترة (منزلق / مفصلي) + زر إضافة قطاع جديد
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              for (final cat in ['الكل', 'منزلق', 'مفصلي'])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(cat),
                    selected: _selectedCatFilter == cat,
                    selectedColor: const Color(0xFFD97706),
                    labelStyle: TextStyle(
                      color: _selectedCatFilter == cat
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedCatFilter = cat),
                  ),
                ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openSectorEditor(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة قطاع جديد',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        // شريط فلترة الشركات بنفس ترتيب المشروع المماثل
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            itemCount: groups.length,
            itemBuilder: (ctx, idx) {
              final grp = groups[idx];
              final isSel = grp == _selectedGroupFilter;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: Text(grp),
                  selected: isSel,
                  selectedColor: const Color(0xFF31869B),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : Colors.black87,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11.5,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedGroupFilter = grp),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final sec = filtered[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildSectorAvatar(sec),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sec.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5),
                                ),
                                Text(
                                  '${sec.companyGroup} • ${sec.category} • سعر المتر: ${sec.pricePerSquareMeter.toStringAsFixed(0)} ج.م/م²',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                          ),
                          SvgProfileWidget(
                            assetPath: sec.primaryProfileSvg,
                            width: 48,
                            height: 48,
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF31869B),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _showSectorCatalogModal(sec),
                            icon: const Icon(Icons.menu_book, size: 16),
                            label: const Text('عرض كتالوج ومقاطع القطاع',
                                style: TextStyle(fontSize: 11.5)),
                          ),
                          if (sec.catalogUrl.isNotEmpty)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: const Color(0xFFB45309),
                              ),
                              onPressed: () {
                                NativeFileService.openExternalUrl(
                                    sec.catalogUrl);
                              },
                              icon: const Icon(Icons.link, size: 16),
                              label: const Text('رابط الكتالوج الرسمي',
                                  style: TextStyle(fontSize: 11.5)),
                            ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _openSectorEditor(existing: sec),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('تعديل القطاع والتخصيمات',
                                style: TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectorAvatar(SectorProfile sec) {
    if (sec.imagePath != null &&
        sec.imagePath!.isNotEmpty &&
        File(sec.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(sec.imagePath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    if (sec.companyLogoAsset != null && sec.companyLogoAsset!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          sec.companyLogoAsset!,
          width: 48,
          height: 48,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.window, color: Color(0xFFB45309), size: 32),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD97706)),
      ),
      child: const Icon(Icons.window, color: Color(0xFFB45309), size: 28),
    );
  }

  /// التبويب الثاني: كتالوجات الألوان (من المشروع المماثل: علم الدين، مصر الإمارات، الكلادينج، الخشابي)
  Widget _buildColorsCataloguesTab() {
    const colorCodes = [
      '1000.jpg',
      '1036.jpg',
      '2013.jpg',
      '2500.jpg',
      '27.jpg',
      '3032.jpg',
      '7003.jpg',
      '7102.jpg',
      '7200.jpg',
      '89.jpg',
      '9006.jpg',
      '9007.jpg',
      'A-7.jpg',
      'C-8.jpg',
      'C3D-3.jpg',
      'CAT-GOLD.jpg',
      'CHG-GOLD.jpg',
      'CS-2.jpg',
      'CS-4.jpg',
      'D-7.jpg',
      'F-685.jpg',
      'F-7.jpg',
      'G-7.jpg',
      'G-8.jpg',
      'G7-3D.jpg',
      'LOS-208.jpg',
      'LOS-8.jpg',
      'MO-3.8.jpg',
      'MO-308.jpg',
      'MO-36.jpg',
      'NO-308.jpg',
      'NO-7.jpg',
      'P-21.jpg',
      'P-8.jpg',
      'PINO-7.jpg',
      'PINO-8.jpg',
      'Q-9.jpg',
      'Q8R-3D.jpg',
      'Q8R.jpg',
      'QA-6.jpg',
      'RA-7.jpg',
      'RO-308.jpg',
      'RO-7.jpg',
      'RS-8.jpg',
      'W-21.jpg',
      'W-4.jpg',
      'W3D-3.jpg',
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: colorCodes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (ctx, i) {
        final f = colorCodes[i];
        final code = f.replaceAll('.jpg', '');
        final path = 'assets/images/catalogues/colors_catalogues/$f';
        return Card(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.color_lens, size: 36),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: const Color(0xFF0F172A),
                child: Text(
                  'كود: $code',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// التبويب الثالث: حاسبة الدورانات والأقواس (من المشروع المماثل بالضبط)
  Widget _buildRadiusCalculatorTab() {
    final double w = double.tryParse(_chordCtrl.text.trim()) ?? 120.0;
    final double h = double.tryParse(_sagittaCtrl.text.trim()) ?? 30.0;
    final double radius = h > 0 ? (h / 2.0) + ((w * w) / (8.0 * h)) : 0.0;
    final double angleRad =
        (radius > 0 && w <= 2 * radius) ? 2.0 * math.asin(w / (2.0 * radius)) : 0.0;
    final double arcLength = radius * angleRad;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/windows/radius.jpg',
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chordCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'طول الوتر / العرض (سم)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _sagittaCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'العمق / سقوط القوس (سم)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ListTile(
                    tileColor: const Color(0xFFFEF3C7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    title: Text(
                      'نصف قطر الدوران (R): ${radius.toStringAsFixed(2)} سم',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      'طول عود القوس الصافي للدوران: ${arcLength.toStringAsFixed(2)} سم (يُضاف له 20 سم ركوب للدرفلة = ${(arcLength + 20).toStringAsFixed(1)} سم)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7F1D1D)),
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

class SectorEditorPage extends StatefulWidget {
  final WorkshopStorage storage;
  final SectorProfile? existingSector;

  const SectorEditorPage({
    super.key,
    required this.storage,
    this.existingSector,
  });

  @override
  State<SectorEditorPage> createState() => _SectorEditorPageState();
}

class _SectorEditorPageState extends State<SectorEditorPage> {
  final _nameCtrl = TextEditingController();
  final _shortPdfNameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _catalogUrlCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _glassWDeductCtrl = TextEditingController();
  final _glassHDeductCtrl = TextEditingController();
  final _fixedGlassDeductCtrl = TextEditingController();
  final _transomDeductCtrl = TextEditingController();

  String _category = 'منزلق';
  String _systemType = 'شباك جرار';
  int _defaultSashCount = 2;
  String? _imagePath;
  List<SectorPart> _parts = [];

  @override
  void initState() {
    super.initState();
    final ex = widget.existingSector;
    if (ex != null) {
      _nameCtrl.text = ex.name;
      _shortPdfNameCtrl.text = ex.shortPdfName;
      _companyCtrl.text = ex.companyGroup;
      _catalogUrlCtrl.text = ex.catalogUrl;
      _priceCtrl.text = ex.pricePerSquareMeter.toStringAsFixed(0);
      _glassWDeductCtrl.text = ex.glassWidthDeductCm.toString();
      _glassHDeductCtrl.text = ex.glassHeightDeductCm.toString();
      _fixedGlassDeductCtrl.text = ex.fixedGlassDeductCm.toString();
      _transomDeductCtrl.text = ex.transomDeductCm.toString();
      _category = ex.isSliding ? 'منزلق' : 'مفصلي';
      _systemType = ex.systemType;
      _defaultSashCount = ex.defaultSashCount;
      _imagePath = ex.imagePath;
      _parts = ex.parts
          .map((p) => SectorPart.fromJson(p.toJson()))
          .toList();
    } else {
      _companyCtrl.text = 'قطاعات الشريف';
      _catalogUrlCtrl.text = 'https://mac-eg.com/';
      _priceCtrl.text = '5500';
      _glassWDeductCtrl.text = '11.4';
      _glassHDeductCtrl.text = '11.4';
      _fixedGlassDeductCtrl.text = '6.4';
      _transomDeductCtrl.text = '5.6';
      _parts = [
        SectorPart(
            id: 'p1',
            name: 'حلق ببار (عرض)',
            role: 'حلق',
            dimensionBasis: 'width',
            offsetCm: 0.0,
            quantityPerWindow: 2,
            svgAssetPath: 'assets/images/svg/profiles/sh/JamBo100/001.svg'),
        SectorPart(
            id: 'p2',
            name: 'حلق ببار (ارتفاع)',
            role: 'حلق',
            dimensionBasis: 'height',
            offsetCm: 0.0,
            quantityPerWindow: 2,
            svgAssetPath: 'assets/images/svg/profiles/sh/JamBo100/001.svg'),
        SectorPart(
            id: 'p3',
            name: 'ضلفة شباك (عرض)',
            role: 'ضلفة',
            dimensionBasis: 'net_width_per_sash',
            offsetCm: -0.6,
            quantityPerWindow: 2,
            multiplyBySashes: true,
            svgAssetPath: 'assets/images/svg/profiles/sh/JamBo100/003.svg'),
        SectorPart(
            id: 'p4',
            name: 'ضلفة شباك (ارتفاع)',
            role: 'ضلفة',
            dimensionBasis: 'net_height',
            offsetCm: -6.8,
            quantityPerWindow: 2,
            multiplyBySashes: true,
            svgAssetPath: 'assets/images/svg/profiles/sh/JamBo100/003.svg'),
        SectorPart(
            id: 'p5',
            name: 'سكينة تداخل',
            role: 'سكينة',
            dimensionBasis: 'net_height',
            offsetCm: -6.8,
            quantityPerWindow: 2,
            svgAssetPath: 'assets/images/svg/profiles/sh/JamBo100/006.svg'),
      ];
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() => _imagePath = picked.path);
      }
    } catch (_) {}
  }

  Future<void> _saveSector() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final sector = SectorProfile(
      id: widget.existingSector?.id ??
          'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      shortPdfName: _shortPdfNameCtrl.text.trim().isEmpty
          ? name
          : _shortPdfNameCtrl.text.trim(),
      category: _category,
      companyGroup: _companyCtrl.text.trim().isEmpty
          ? 'قطاعات الشريف'
          : _companyCtrl.text.trim(),
      systemType: _systemType,
      defaultSashCount: _defaultSashCount,
      imagePath: _imagePath,
      companyLogoAsset: widget.existingSector?.companyLogoAsset ??
          'assets/images/windows/systems/s001.png',
      profileSvgFolder: widget.existingSector?.profileSvgFolder ??
          'assets/images/svg/profiles/sh/JamBo100',
      fixedTransomSvg: widget.existingSector?.fixedTransomSvg,
      fixedBeadSingleSvg: widget.existingSector?.fixedBeadSingleSvg,
      fixedBeadDoubleSvg: widget.existingSector?.fixedBeadDoubleSvg,
      catalogUrl: _catalogUrlCtrl.text.trim(),
      pricePerSquareMeter: double.tryParse(_priceCtrl.text.trim()) ?? 5000.0,
      glassWidthDeductCm:
          double.tryParse(_glassWDeductCtrl.text.trim()) ?? 11.4,
      glassHeightDeductCm:
          double.tryParse(_glassHDeductCtrl.text.trim()) ?? 11.4,
      fixedGlassDeductCm:
          double.tryParse(_fixedGlassDeductCtrl.text.trim()) ?? 6.4,
      transomDeductCm:
          double.tryParse(_transomDeductCtrl.text.trim()) ?? 5.6,
      isCustom: true,
      parts: _parts,
    );

    await widget.storage.addOrUpdateSector(sector);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B110A),
        foregroundColor: Colors.white,
        title: Text(widget.existingSector == null
            ? 'إضافة قطاع جديد ورابط الكتالوج'
            : 'تعديل القطاع والكتالوج'),
        actions: [
          TextButton.icon(
            onPressed: _saveSector,
            icon: const Icon(Icons.save, color: Color(0xFFF59E0B)),
            label: const Text('حفظ',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD97706)),
                          ),
                          child: (_imagePath != null &&
                                  File(_imagePath!).existsSync())
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Image.file(File(_imagePath!),
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.add_a_photo,
                                  color: Color(0xFFB45309)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'اسم القطاع الكامل',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _shortPdfNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'الاسم المختصر في الـ PDF (مثل: UPVC كبير)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _category,
                          decoration: const InputDecoration(
                            labelText: 'منزلق أم مفصلي',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'منزلق', child: Text('منزلق (جرار)')),
                            DropdownMenuItem(
                                value: 'مفصلي', child: Text('مفصلي / قلاب')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _category = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _companyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الشركة / المجموعة',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _catalogUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رابط كتالوج القطاع (URL)',
                      prefixIcon: Icon(Icons.link),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر المتر المربع (ج.م)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _glassWDeductCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'خصم عرض الزجاج (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _glassHDeductCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'خصم طول الزجاج (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fixedGlassDeductCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'خصم زجاج الثابت (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _transomDeductCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'خصم السؤاس (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
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
