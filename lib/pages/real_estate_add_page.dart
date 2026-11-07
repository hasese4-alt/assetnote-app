import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealEstateAddPage extends StatefulWidget {
  const RealEstateAddPage({
    super.key,
    required this.year,
    required this.month,
    this.preselectedC1Id,
    this.preselectedC2Id,
  });

  final int year;
  final int month;
  final String? preselectedC1Id;
  final String? preselectedC2Id;

  @override
  State<RealEstateAddPage> createState() => _RealEstateAddPageState();
}

class _RealEstateAddPageState extends State<RealEstateAddPage> {
  late final AssetsRepository _repository;

  final _nameCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _downPaymentCtrl = TextEditingController();
  final _loanAmountCtrl = TextEditingController();
  final _loanTermYearsCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _monthlyPaymentCtrl = TextEditingController();
  final _managementFeeCtrl = TextEditingController();
  final _repairReserveCtrl = TextEditingController();
  final _propertyTaxCtrl = TextEditingController();
  final _otherCostsCtrl = TextEditingController();
  final _virtualRentCtrl = TextEditingController();
  final _estimatedValueCtrl = TextEditingController();

  DateTime _acquisitionDate = DateTime.now();
  DateTime _loanStartDate = DateTime.now();

  List<Map<String, dynamic>> _parentCategories = [];
  Map<String, List<Map<String, dynamic>>> _childCategories = {};
  String? _selectedC1Id;
  String? _selectedC2Id;

  bool _saving = false;
  final _dateFmt = DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _selectedC1Id = widget.preselectedC1Id;
    _selectedC2Id = widget.preselectedC2Id;
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _downPaymentCtrl.dispose();
    _loanAmountCtrl.dispose();
    _loanTermYearsCtrl.dispose();
    _interestRateCtrl.dispose();
    _monthlyPaymentCtrl.dispose();
    _managementFeeCtrl.dispose();
    _repairReserveCtrl.dispose();
    _propertyTaxCtrl.dispose();
    _otherCostsCtrl.dispose();
    _virtualRentCtrl.dispose();
    _estimatedValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final h = await _repository.fetchCategoryHierarchy();
    if (!mounted) return;
    setState(() {
      _parentCategories = h.parentCategories;
      _childCategories = h.childCategories;
    });
  }

  Future<void> _pickDate({required bool isAcquisition}) async {
    final initial = isAcquisition ? _acquisitionDate : _loanStartDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isAcquisition) {
        _acquisitionDate = picked;
      } else {
        _loanStartDate = picked;
      }
    });
  }

  int _toInt(TextEditingController ctrl) =>
      int.tryParse(ctrl.text.replaceAll(',', '').replaceAll('¥', '')) ?? 0;

  double _toDouble(TextEditingController ctrl) =>
      double.tryParse(ctrl.text) ?? 0.0;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showMissingFieldDialog(context, '物件名を入力してください。');
      return;
    }
    if (_selectedC1Id == null) {
      showMissingFieldDialog(context, 'カテゴリを選択してください。');
      return;
    }
    final purchasePrice = _toInt(_purchasePriceCtrl);
    if (purchasePrice == 0) {
      showMissingFieldDialog(context, '取得価格を入力してください。');
      return;
    }
    final estimatedValue = _toInt(_estimatedValueCtrl);
    if (estimatedValue == 0) {
      showMissingFieldDialog(context, '現在の推定価値を入力してください。');
      return;
    }

    setState(() => _saving = true);
    try {
      final loanAmount = _toInt(_loanAmountCtrl);
      await _repository.insertRealEstateAsset(
        name: name,
        category1Id: _selectedC1Id,
        category2Id: _selectedC2Id,
        estimatedValue: estimatedValue,
        purchasePrice: purchasePrice,
        downPayment: _toInt(_downPaymentCtrl),
        acquisitionDate: _acquisitionDate.toIso8601String().substring(0, 10),
        originalLoanAmount: loanAmount,
        loanStartDate: _loanStartDate.toIso8601String().substring(0, 10),
        loanTermMonths: (int.tryParse(_loanTermYearsCtrl.text) ?? 35) * 12,
        interestRatePercent: _toDouble(_interestRateCtrl),
        monthlyPayment: _toInt(_monthlyPaymentCtrl),
        currentLoanBalance: loanAmount,
        managementFee: _toInt(_managementFeeCtrl),
        repairReserveFund: _toInt(_repairReserveCtrl),
        propertyTaxMonthly: _toInt(_propertyTaxCtrl),
        otherMonthlyCosts: _toInt(_otherCostsCtrl),
        virtualMonthlyRent: _toInt(_virtualRentCtrl),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final dividerColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    final labelColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final hintColor =
        isDark ? const Color(0xFF636366) : const Color(0xFFAEAEB2);
    final sectionColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6D6D72);
    final subItems = _childCategories[_selectedC1Id] ?? [];

    Widget buildCard(List<Widget> rows) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: 16,
                    color: dividerColor),
              rows[i],
            ],
          ],
        ),
      );
    }

    Widget buildRow(String label, Widget child) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: labelColor)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
    }

    Widget buildTextField(
      TextEditingController ctrl, {
      String hint = '0',
      bool isDecimal = false,
      String? prefix,
    }) {
      return Row(
        children: [
          if (prefix != null)
            Text(prefix,
                style: TextStyle(fontSize: 17, color: hintColor)),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: isDecimal),
              inputFormatters: isDecimal
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: TextStyle(color: hintColor, fontSize: 17),
              ),
            ),
          ),
        ],
      );
    }

    Widget buildDateRow(
        String label, DateTime date, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: buildRow(
          label,
          Row(
            children: [
              Expanded(
                child: Text(_dateFmt.format(date),
                    style: const TextStyle(fontSize: 17)),
              ),
              Icon(Icons.chevron_right, size: 18, color: hintColor),
            ],
          ),
        ),
      );
    }

    Widget buildSection(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sectionColor)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          '不動産を追加',
          style:
              theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 基本情報 ──────────────────────────────────────────
          buildSection('基本情報'),
          buildCard([
            buildRow('物件名',
                buildTextField(_nameCtrl, hint: '例: ○○マンション101号室')),
            buildDateRow(
                '取得日', _acquisitionDate, () => _pickDate(isAcquisition: true)),
            buildRow(
              'カテゴリ',
              SizedBox(
                height: 22,
                child: DropdownButton<String>(
                  value: _selectedC1Id,
                  hint: Text('選択してください',
                      style: TextStyle(color: hintColor, fontSize: 17)),
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  style: TextStyle(
                      fontSize: 17, color: theme.colorScheme.onSurface),
                  items: _parentCategories
                      .map((p) => DropdownMenuItem(
                            value: p['id'] as String,
                            child: Text(p['name'] as String,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedC1Id = v;
                    _selectedC2Id = null;
                  }),
                ),
              ),
            ),
            if (_selectedC1Id != null)
              buildRow(
                'サブカテゴリ',
                SizedBox(
                  height: 22,
                  child: DropdownButton<String>(
                    value: _selectedC2Id,
                    hint: Text('なし',
                        style: TextStyle(color: hintColor, fontSize: 17)),
                    underline: const SizedBox.shrink(),
                    isExpanded: true,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    style: TextStyle(
                        fontSize: 17, color: theme.colorScheme.onSurface),
                    items: subItems
                        .map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'] as String,
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface)),
                            ))
                        .toList(),
                    onChanged: subItems.isEmpty
                        ? null
                        : (v) => setState(() => _selectedC2Id = v),
                  ),
                ),
              ),
          ]),

          // ── ローン情報 ────────────────────────────────────────
          buildSection('取得・ローン情報'),
          buildCard([
            buildRow('取得価格',
                buildTextField(_purchasePriceCtrl, hint: '例: 45000000', prefix: '¥')),
            buildRow('頭金',
                buildTextField(_downPaymentCtrl, hint: '例: 5000000', prefix: '¥')),
            buildRow('借入額',
                buildTextField(_loanAmountCtrl, hint: '例: 40000000', prefix: '¥')),
            buildDateRow('ローン開始日', _loanStartDate,
                () => _pickDate(isAcquisition: false)),
            buildRow('返済期間（年）',
                buildTextField(_loanTermYearsCtrl, hint: '例: 35')),
            buildRow('現在の金利（%）',
                buildTextField(_interestRateCtrl, hint: '例: 0.475', isDecimal: true)),
            buildRow('月々返済額',
                buildTextField(_monthlyPaymentCtrl, hint: '例: 100000', prefix: '¥')),
          ]),

          // ── 月次コスト ────────────────────────────────────────
          buildSection('月次コスト（月額）'),
          buildCard([
            buildRow('管理費',
                buildTextField(_managementFeeCtrl, hint: '例: 15000', prefix: '¥')),
            buildRow('修繕積立金',
                buildTextField(_repairReserveCtrl, hint: '例: 8000', prefix: '¥')),
            buildRow('固定資産税（月換算）',
                buildTextField(_propertyTaxCtrl, hint: '例: 10000', prefix: '¥')),
            buildRow('その他',
                buildTextField(_otherCostsCtrl, hint: '0', prefix: '¥')),
          ]),

          // ── 賃貸比較 ──────────────────────────────────────────
          buildSection('賃貸比較'),
          buildCard([
            buildRow('仮想家賃（もし賃貸なら）',
                buildTextField(_virtualRentCtrl, hint: '例: 150000', prefix: '¥')),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              '同等の物件を賃貸した場合の月額家賃を入力してください。',
              style: TextStyle(fontSize: 12, color: sectionColor),
            ),
          ),

          // ── 現在の状態 ────────────────────────────────────────
          buildSection('現在の状態'),
          buildCard([
            buildRow('現在の推定価値',
                buildTextField(_estimatedValueCtrl, hint: '例: 46000000', prefix: '¥')),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              '純資産 = 推定価値 − 残債（登録時は借入額全額）',
              style: TextStyle(fontSize: 12, color: sectionColor),
            ),
          ),

          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: const StadiumBorder(),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('保存', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
