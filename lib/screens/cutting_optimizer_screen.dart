import 'package:flutter/material.dart';
import '../models/workshop_models.dart';
import '../services/workshop_storage.dart';

class CuttingOptimizerScreen extends StatefulWidget {
  final WorkshopStorage storage;
  const CuttingOptimizerScreen({super.key, required this.storage});

  @override
  State<CuttingOptimizerScreen> createState() => _CuttingOptimizerScreenState();
}

class _CuttingOptimizerScreenState extends State<CuttingOptimizerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1D Bar Cutting State
  final _stockBarCtrl = TextEditingController(text: '600');
  final _kerfMmCtrl = TextEditingController(text: '4');
  final _pieceLenCtrl = TextEditingController();
  final _pieceQtyCtrl = TextEditingController(text: '2');
  final List<Map<String, num>> _barRequests = [
    {'length': 213.0, 'qty': 4},
    {'length': 138.0, 'qty': 4},
    {'length': 99.0, 'qty': 4},
  ];

  // 2D Board Cutting State
  final _boardWCtrl = TextEditingController(text: '244');
  final _boardHCtrl = TextEditingController(text: '122');
  final _panelWCtrl = TextEditingController();
  final _panelHCtrl = TextEditingController();
  final _panelQtyCtrl = TextEditingController(text: '2');
  final List<Map<String, num>> _panelRequests = [
    {'w': 72.0, 'h': 58.0, 'qty': 4},
    {'w': 60.0, 'h': 58.0, 'qty': 2},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _stockBarCtrl.text = widget
        .storage.pricingSettings.defaultStockBarLengthCm
        .toStringAsFixed(0);
    _kerfMmCtrl.text =
        widget.storage.pricingSettings.defaultSawKerfMm.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stockBarCtrl.dispose();
    _kerfMmCtrl.dispose();
    _pieceLenCtrl.dispose();
    _pieceQtyCtrl.dispose();
    _boardWCtrl.dispose();
    _boardHCtrl.dispose();
    _panelWCtrl.dispose();
    _panelHCtrl.dispose();
    _panelQtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double stockLen = double.tryParse(_stockBarCtrl.text) ?? 600.0;
    final double kerfMm = double.tryParse(_kerfMmCtrl.text) ?? 4.0;

    final List<double> expandedPieces = [];
    for (final req in _barRequests) {
      final double l = (req['length'] ?? 0).toDouble();
      final int q = (req['qty'] ?? 0).toInt();
      for (int i = 0; i < q; i++) {
        expandedPieces.add(l);
      }
    }

    final barPlans = WorkshopStorage.optimize1DBars(
      requiredPiecesCm: expandedPieces,
      stockLengthCm: stockLen,
      sawKerfMm: kerfMm,
    );

    return Column(
      children: [
        Container(
          color: const Color(0xFF1E293B),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFF59E0B),
            unselectedLabelColor: Colors.white70,
            indicatorColor: const Color(0xFFF59E0B),
            tabs: const [
              Tab(
                icon: Icon(Icons.straighten, size: 18),
                text: 'تقسيم الأعواد (600 / 650 سم)',
              ),
              Tab(
                icon: Icon(Icons.grid_view, size: 18),
                text: 'تقسيم الألواح (الخشب والكلادينج)',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _build1DBarsTab(stockLen, barPlans),
              _build2DBoardsOptimizer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _build1DBarsTab(double stockLen, List<BarCutPlan> barPlans) {
    double totalWaste = 0;
    for (final p in barPlans) {
      totalWaste += p.wasteLengthCm;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Text(
                        'إعدادات طول العود وسُمك صينية المنشار:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B)),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _barRequests.clear()),
                        icon: const Icon(Icons.delete_sweep,
                            color: Colors.red, size: 18),
                        label: const Text('مسح الكل',
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stockBarCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'طول العود (600 أو 650 سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _kerfMmCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'سمك المنشار (مم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _pieceLenCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'طول القطعة المطلوبة (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _pieceQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'العدد',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                        ),
                        onPressed: () {
                          final l =
                              double.tryParse(_pieceLenCtrl.text.trim()) ?? 0.0;
                          final q =
                              int.tryParse(_pieceQtyCtrl.text.trim()) ?? 1;
                          if (l > 0 && l <= stockLen && q > 0) {
                            setState(() {
                              _barRequests.add({'length': l, 'qty': q});
                              _pieceLenCtrl.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('إضافة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_barRequests.length, (index) {
                      final r = _barRequests[index];
                      return InputChip(
                        backgroundColor: const Color(0xFFFEF3C7),
                        label: Text(
                          '${r['length']} سم × ${r['qty']} قطعة',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onDeleted: () =>
                            setState(() => _barRequests.removeAt(index)),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ملخص نتيجة تقسيم الأعواد
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إجمالي الأعواد المطلوبة: ${barPlans.length} عود',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFFFDE68A),
                  ),
                ),
                Text(
                  'إجمالي الفضلات: ${totalWaste.toStringAsFixed(1)} سم',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // رسم تخطيطي ملون لكل عود ومقاسات القطع والفضلة (مثل المشروع المماثل بالضبط)
          ...barPlans.map((plan) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'العود رقم #${plan.barNumber} (${stockLen.toStringAsFixed(0)} سم)',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'المستخدم: ${plan.usedLengthCm} سم | الفضلة: ${plan.wasteLengthCm} سم (${plan.wastePercentage.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // شريط بصري مقسم بنسب أطوال القطع والفضلة
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 30,
                          child: Row(
                            children: [
                              ...plan.cutsCm.map((cut) {
                                final int flexVal =
                                    ((cut / stockLen) * 1000).round().clamp(20, 1000);
                                return Expanded(
                                  flex: flexVal,
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 1.5),
                                    color: const Color(0xFF31869B),
                                    alignment: Alignment.center,
                                    child: Text(
                                      cut.toStringAsFixed(0),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.clip,
                                    ),
                                  ),
                                );
                              }),
                              if (plan.wasteLengthCm > 0.5)
                                Expanded(
                                  flex: ((plan.wasteLengthCm / stockLen) * 1000)
                                      .round()
                                      .clamp(25, 1000),
                                  child: Container(
                                    color: const Color(0xFFEF4444),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'فضلة ${plan.wasteLengthCm.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.clip,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تفصيل القص: [ ${plan.cutsCm.map((e) => "${e.toStringAsFixed(1)} سم").join("  +  ")} ]',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _build2DBoardsOptimizer() {
    final double bW = double.tryParse(_boardWCtrl.text) ?? 244.0;
    final double bH = double.tryParse(_boardHCtrl.text) ?? 122.0;
    final double boardAreaM2 = (bW / 100.0) * (bH / 100.0);

    double totalPanelsAreaM2 = 0.0;
    int totalPanelsCount = 0;
    for (final p in _panelRequests) {
      final double w = (p['w'] ?? 0).toDouble();
      final double h = (p['h'] ?? 0).toDouble();
      final int q = (p['qty'] ?? 0).toInt();
      totalPanelsAreaM2 += ((w / 100.0) * (h / 100.0)) * q;
      totalPanelsCount += q;
    }

    final double rawBoards =
        boardAreaM2 > 0 ? (totalPanelsAreaM2 / (boardAreaM2 * 0.88)) : 0.0;
    final int fullBoardsNeeded = rawBoards.ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مقاس اللوح القياسي (خشب: 244×122 سم أو كلادينج/فايبر: 280×130 سم):',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _boardWCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'طول اللوح القياسي (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _boardHCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'عرض اللوح القياسي (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _panelWCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'طول القطعة (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _panelHCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عرض القطعة (سم)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _panelQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'العدد',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final w =
                              double.tryParse(_panelWCtrl.text.trim()) ?? 0.0;
                          final h =
                              double.tryParse(_panelHCtrl.text.trim()) ?? 0.0;
                          final q =
                              int.tryParse(_panelQtyCtrl.text.trim()) ?? 1;
                          if (w > 0 && h > 0 && q > 0) {
                            setState(() {
                              _panelRequests.add({'w': w, 'h': h, 'qty': q});
                              _panelWCtrl.clear();
                              _panelHCtrl.clear();
                            });
                          }
                        },
                        child: const Text('إضافة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: List.generate(_panelRequests.length, (idx) {
                      final p = _panelRequests[idx];
                      return InputChip(
                        label: Text(
                            '${p['w']}×${p['h']} سم (العدد: ${p['qty']})'),
                        onDeleted: () =>
                            setState(() => _panelRequests.removeAt(idx)),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFF0FDF4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجمالي القطع المضافة: $totalPanelsCount قطعة (إجمالي المساحة الصافية: ${totalPanelsAreaM2.toStringAsFixed(2)} م²)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'عدد الألواح المطلوب شراؤها (بمقاس ${bW.toStringAsFixed(0)}×${bH.toStringAsFixed(0)} سم): $fullBoardsNeeded لوح (${rawBoards.toStringAsFixed(2)} لوح)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF15803D),
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
