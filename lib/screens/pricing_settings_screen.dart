import 'package:flutter/material.dart';
import '../models/workshop_models.dart';
import '../services/workshop_storage.dart';
import '../widgets/svg_profile_widget.dart';

class PricingSettingsScreen extends StatefulWidget {
  final WorkshopStorage storage;
  const PricingSettingsScreen({super.key, required this.storage});

  @override
  State<PricingSettingsScreen> createState() => _PricingSettingsScreenState();
}

class _PricingSettingsScreenState extends State<PricingSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _baselineBrownGlassCtrl;
  late TextEditingController _spacerPriceCtrl;
  late TextEditingController _georgianPriceCtrl;
  late TextEditingController _flyScreenPriceCtrl;
  late TextEditingController _shutterPriceCtrl;
  late TextEditingController _fanPriceCtrl;
  late TextEditingController _defaultArchPriceCtrl;
  late TextEditingController _barLenCtrl;
  late TextEditingController _kerfCtrl;
  late TextEditingController _note1Ctrl;
  late TextEditingController _note2Ctrl;
  late TextEditingController _note3Ctrl;
  late TextEditingController _termsCtrl;
  bool _minOneM2 = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final s = widget.storage.pricingSettings;
    _baselineBrownGlassCtrl = TextEditingController(
        text: s.baselineBrownReflectiveGlassPricePerM2.toStringAsFixed(0));
    _spacerPriceCtrl =
        TextEditingController(text: s.doubleSpacerPricePerMeter.toString());
    _georgianPriceCtrl =
        TextEditingController(text: s.georgianBarPricePerMeter.toString());
    _flyScreenPriceCtrl =
        TextEditingController(text: s.flyScreenPricePerM2.toString());
    _shutterPriceCtrl =
        TextEditingController(text: s.shutterPricePerM2.toString());
    _fanPriceCtrl = TextEditingController(text: s.exhaustFanPrice.toString());
    _defaultArchPriceCtrl =
        TextEditingController(text: s.defaultArchPrice.toStringAsFixed(0));
    _barLenCtrl =
        TextEditingController(text: s.defaultStockBarLengthCm.toString());
    _kerfCtrl = TextEditingController(text: s.defaultSawKerfMm.toString());
    _note1Ctrl = TextEditingController(text: s.pdfNoteLine1);
    _note2Ctrl = TextEditingController(text: s.pdfNoteLine2);
    _note3Ctrl = TextEditingController(text: s.pdfNoteLine3);
    _termsCtrl = TextEditingController(text: s.termsAndConditions);
    _minOneM2 = s.enforceMinimumOneSquareMeter;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baselineBrownGlassCtrl.dispose();
    _spacerPriceCtrl.dispose();
    _georgianPriceCtrl.dispose();
    _flyScreenPriceCtrl.dispose();
    _shutterPriceCtrl.dispose();
    _fanPriceCtrl.dispose();
    _defaultArchPriceCtrl.dispose();
    _barLenCtrl.dispose();
    _kerfCtrl.dispose();
    _note1Ctrl.dispose();
    _note2Ctrl.dispose();
    _note3Ctrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGeneralPricing() async {
    final old = widget.storage.pricingSettings;
    final updated = PricingSettings(
      baselineBrownReflectiveGlassPricePerM2:
          double.tryParse(_baselineBrownGlassCtrl.text.trim()) ?? 600.0,
      doubleSpacerPricePerMeter:
          double.tryParse(_spacerPriceCtrl.text.trim()) ?? 150.0,
      georgianBarPricePerMeter:
          double.tryParse(_georgianPriceCtrl.text.trim()) ?? 85.0,
      flyScreenPricePerM2:
          double.tryParse(_flyScreenPriceCtrl.text.trim()) ?? 250.0,
      shutterPricePerM2:
          double.tryParse(_shutterPriceCtrl.text.trim()) ?? 1800.0,
      exhaustFanPrice: double.tryParse(_fanPriceCtrl.text.trim()) ?? 350.0,
      defaultArchPrice:
          double.tryParse(_defaultArchPriceCtrl.text.trim()) ?? 600.0,
      defaultStockBarLengthCm:
          double.tryParse(_barLenCtrl.text.trim()) ?? 600.0,
      defaultSawKerfMm: double.tryParse(_kerfCtrl.text.trim()) ?? 4.0,
      enforceMinimumOneSquareMeter: _minOneM2,
      companyName: old.companyName,
      companySubtitle: old.companySubtitle,
      companyPhones: old.companyPhones,
      companyAddress: old.companyAddress,
      pdfNoteLine1: _note1Ctrl.text.trim(),
      pdfNoteLine2: _note2Ctrl.text.trim(),
      pdfNoteLine3: _note3Ctrl.text.trim(),
      pdfNoteLine4: old.pdfNoteLine4,
      pdfNoteLine5: old.pdfNoteLine5,
      pdfNoteLine6: old.pdfNoteLine6,
      termsAndConditions: _termsCtrl.text.trim(),
    );
    await widget.storage.updatePricingSettings(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تم حفظ قائمة التسعير وإعدادات الـ PDF بنجاح')),
    );
  }

  void _editSectorPriceDialog(SectorProfile sector) {
    final priceCtrl = TextEditingController(
        text: sector.pricePerSquareMeter.toStringAsFixed(0));
    final barPriceCtrl =
        TextEditingController(text: sector.barPrice.toStringAsFixed(0));
    final urlCtrl = TextEditingController(text: sector.catalogUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسعير قطاع: ${sector.name}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعر المتر المربع بالعاكس البني (ج.م)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: barPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعر العود 6 متر (ج.م)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'رابط كتالوج القطاع',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final p = double.tryParse(priceCtrl.text.trim()) ??
                  sector.pricePerSquareMeter;
              final bp =
                  double.tryParse(barPriceCtrl.text.trim()) ?? sector.barPrice;
              await widget.storage.updateSectorPrice(
                sector.id,
                p,
                barPrice: bp,
                catalogUrl: urlCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ التحديث'),
          ),
        ],
      ),
    );
  }

  void _showGlassDialog({GlassTypeItem? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null
            ? existing.pricePerSquareMeter.toStringAsFixed(0)
            : '600');
    bool isDefaultBase = existing?.isDefaultBaseline ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة نوع زجاج جديد' : 'تعديل الزجاج'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'اسم ومواصفات الزجاج',
                  hintText: 'مثال: عاكس بني 6 مم / عاكس أزرق 6 مم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر المتر المربع (ج.م)',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                    'هل هو الزجاج الافتراضي الأساسي (العاكس البني)؟',
                    style: TextStyle(fontSize: 12.5)),
                value: isDefaultBase,
                onChanged: (v) => setDialogState(() => isDefaultBase = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final price = double.tryParse(priceCtrl.text.trim()) ?? 600.0;
                await widget.storage.addOrUpdateGlassType(
                  GlassTypeItem(
                    id: existing?.id ??
                        'glass_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    pricePerSquareMeter: price,
                    isDefaultBaseline: isDefaultBase,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccessoryDialog({AccessoryPriceItem? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'طقم');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.price.toStringAsFixed(0) : '150');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(existing == null ? 'إضافة بند إكسسوار' : 'تعديل سعر الإكسسوار'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الإكسسوار / الخامة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                labelText: 'الوحدة (طقم / قطعة / متر مربع / متر طولي)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر (ج.م)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await widget.storage.addOrUpdateAccessory(
                AccessoryPriceItem(
                  id: existing?.id ??
                      'acc_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  unit: unitCtrl.text.trim().isEmpty
                      ? 'طقم'
                      : unitCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
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
                Tab(text: '1. أسعار القطاعات'),
                Tab(text: '2. أسعار الزجاج'),
                Tab(text: '3. الإكسسوارات والـ PDF'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSectorsPricingTab(),
                _buildGlassPricingTab(),
                _buildAccessoriesAndSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorsPricingTab() {
    final sectors = widget.storage.sectors;
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: sectors.length,
      itemBuilder: (ctx, i) {
        final sec = sectors[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: SvgProfileWidget(
              assetPath: sec.primaryProfileSvg,
              width: 44,
              height: 44,
            ),
            title: Text(
              sec.name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: Text(
                '${sec.companyGroup} • ${sec.category} • سعر المتر محسوب بالعاكس البني كـ Default'),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E9C),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _editSectorPriceDialog(sec),
              icon: const Icon(Icons.edit, size: 15),
              label:
                  Text('${sec.pricePerSquareMeter.toStringAsFixed(0)} ج.م/م²'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassPricingTab() {
    final glasses = widget.storage.glassTypes;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD97706)),
          ),
          child: const Text(
            '💡 قاعدة تسعير الزجاج: السعر الافتراضي للمتر المسطح للشباك محسوب دائماً بالاعتماد على "الزجاج العاكس البني" باعتباره الديفولت الطبيعي. إذا اختار العميل زجاجاً أغلى يضاف الفارق، وإذا اختار زجاجاً أرخص يرفض النظام خصم الفارق.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7F1D1D),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _showGlassDialog(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة نوع زجاج جديد لقائمة التسعير'),
        ),
        const SizedBox(height: 10),
        ...glasses.map((g) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: g.isDefaultBaseline ? const Color(0xFFFFFBEB) : Colors.white,
              child: ListTile(
                title: Text(
                  g.name.replaceAll('\n', ' '),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                    '${g.isDefaultBaseline ? "⭐ الزجاج الافتراضي الأساسي (الديفولت)" : "زجاج اختياري"} • السماكة: ${g.thickness}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${g.pricePerSquareMeter.toStringAsFixed(0)} ج.م/م²',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                        fontSize: 13.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit,
                          size: 18, color: Color(0xFF1D4ED8)),
                      onPressed: () => _showGlassDialog(existing: g),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () => widget.storage.deleteGlassType(g.id),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildAccessoriesAndSettingsTab() {
    final accs = widget.storage.accessories;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'قائمة تسعير الإكسسوارات (رينو، عضم، ميجا، تراك، مانع ارتجاج، عجل، مقابض):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF7F1D1D)),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showAccessoryDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('إضافة إكسسوار'),
                    ),
                  ],
                ),
                const Divider(),
                ...accs.map((a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('الوحدة: ${a.unit}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${a.price.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D))),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showAccessoryDialog(existing: a),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            onPressed: () =>
                                widget.storage.deleteAccessory(a.id),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إعدادات التسعير الافتراضية وبنود عقد الـ PDF:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1D4ED8)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _baselineBrownGlassCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر العاكس البني الافتراضي (ج.م)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _defaultArchPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر الدوران الافتراضي (ج.م)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _spacerPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر متر السبيسر (ج.م)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _georgianPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر متر الجورجيا (ج.م)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barLenCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'طول العود القياسي (سم)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _kerfCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سمك صينية المنشار (مم)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'احتساب أي شباك أقل من 1 م² على أنه 1.00 م² كحد أدنى؟',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  value: _minOneM2,
                  onChanged: (v) => setState(() => _minOneM2 = v),
                ),
                const Divider(),
                TextField(
                  controller: _note1Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'سطر الملاحظة الأولى في الـ PDF',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _note2Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'سطر شهادة الجودة والاكسسوارات في الـ PDF',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _termsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شروط التعاقد في الـ PDF',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saveGeneralPricing,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ جميع إعدادات التسعير والـ PDF'),
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
