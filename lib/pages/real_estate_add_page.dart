import 'package:asset_note/theme/app_tokens.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/app_dialogs.dart';
import 'package:asset_note/utils/real_estate_math.dart';
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
  })  : editAssetId = null,
        initialName = null,
        initialDetails = null;

  /// 登録済みの物件情報（取得・ローン条件など）を編集する。
  /// 保存すると新しい物件名を返して閉じる。
  const RealEstateAddPage.edit({
    super.key,
    required int assetId,
    required String this.initialName,
    required Map<String, dynamic> this.initialDetails,
  })  : editAssetId = assetId,
        year = 0,
        month = 0,
        preselectedC1Id = null,
        preselectedC2Id = null;

  final int year;
  final int month;
  final String? preselectedC1Id;
  final String? preselectedC2Id;
  final int? editAssetId;
  final String? initialName;
  final Map<String, dynamic>? initialDetails;

  bool get isEdit => editAssetId != null;

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
  final _shareNumCtrl = TextEditingController(text: '1');
  final _shareDenCtrl = TextEditingController(text: '1');
  final _landPriceCtrl = TextEditingController();
  final _buildingPriceCtrl = TextEditingController();
  final _initialCostsCtrl = TextEditingController();
  final _otherCostsTotalCtrl = TextEditingController();
  final _otherCostsMemoCtrl = TextEditingController();
  final _tcMoveInYearCtrl = TextEditingController();
  final _tcRateCtrl = TextEditingController(text: '0.7');
  final _tcYearsCtrl = TextEditingController(text: '13');
  final _tcLoanLimitCtrl = TextEditingController();
  final _tcAnnualCapCtrl = TextEditingController();

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
    if (widget.isEdit) {
      _fillFromDetails(widget.initialName ?? '', widget.initialDetails ?? {});
    } else {
      _loadCategories();
    }
  }

  void _fillFromDetails(String name, Map<String, dynamic> d) {
    String intText(String key, [int fallback = 0]) =>
        ((d[key] as num?)?.toInt() ?? fallback).toString();
    DateTime dateOf(String key) =>
        DateTime.tryParse(d[key] as String? ?? '') ?? DateTime.now();

    _nameCtrl.text = name;
    _acquisitionDate = dateOf('acquisition_date');
    _loanStartDate = dateOf('loan_start_date');
    _shareNumCtrl.text = intText('ownership_share_numerator', 1);
    _shareDenCtrl.text = intText('ownership_share_denominator', 1);
    _purchasePriceCtrl.text = intText('purchase_price');
    _landPriceCtrl.text = intText('land_price');
    _buildingPriceCtrl.text = intText('building_price');
    _initialCostsCtrl.text = intText('capitalized_initial_costs');
    _downPaymentCtrl.text = intText('down_payment');
    _loanAmountCtrl.text = intText('original_loan_amount');
    final termMonths = (d['loan_term_months'] as num?)?.toInt() ?? 0;
    _loanTermYearsCtrl.text = termMonths > 0 ? (termMonths ~/ 12).toString() : '';

    final otherCosts = (d['other_initial_costs'] as num?)?.toInt() ?? 0;
    _otherCostsTotalCtrl.text = otherCosts > 0 ? otherCosts.toString() : '';
    _otherCostsMemoCtrl.text = d['other_initial_costs_memo'] as String? ?? '';

    final tc = TaxCreditSettings.fromDetails(d);
    _tcMoveInYearCtrl.text = tc.moveInYear?.toString() ?? '';
    _tcRateCtrl.text = tc.ratePercent.toString();
    _tcYearsCtrl.text = tc.years.toString();
    _tcLoanLimitCtrl.text = tc.loanLimit > 0 ? tc.loanLimit.toString() : '';
    _tcAnnualCapCtrl.text = tc.annualCap > 0 ? tc.annualCap.toString() : '';
  }

  TaxCreditSettings _taxCreditSettings() {
    final moveIn = int.tryParse(_tcMoveInYearCtrl.text);
    return TaxCreditSettings(
      moveInYear: moveIn != null && moveIn > 0 ? moveIn : null,
      ratePercent: double.tryParse(_tcRateCtrl.text) ?? 0.7,
      years: int.tryParse(_tcYearsCtrl.text) ?? 13,
      loanLimit: _toInt(_tcLoanLimitCtrl),
      annualCap: _toInt(_tcAnnualCapCtrl),
    );
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
    _shareNumCtrl.dispose();
    _shareDenCtrl.dispose();
    _landPriceCtrl.dispose();
    _buildingPriceCtrl.dispose();
    _initialCostsCtrl.dispose();
    _otherCostsTotalCtrl.dispose();
    _otherCostsMemoCtrl.dispose();
    _tcMoveInYearCtrl.dispose();
    _tcRateCtrl.dispose();
    _tcYearsCtrl.dispose();
    _tcLoanLimitCtrl.dispose();
    _tcAnnualCapCtrl.dispose();
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
    if (widget.isEdit) {
      await _saveEdit(name);
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
    final shareNum = _toInt(_shareNumCtrl);
    final shareDen = _toInt(_shareDenCtrl);
    if (shareNum <= 0 || shareDen <= 0 || shareNum > shareDen) {
      showMissingFieldDialog(context, '持分を正しく入力してください（例: 1 / 2）。');
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
        ownershipShareNumerator: shareNum,
        ownershipShareDenominator: shareDen,
        landPrice: _toInt(_landPriceCtrl),
        buildingPrice: _toInt(_buildingPriceCtrl),
        capitalizedInitialCosts: _toInt(_initialCostsCtrl),
        otherInitialCosts: _toInt(_otherCostsTotalCtrl),
        otherInitialCostsMemo: _otherCostsMemoCtrl.text.trim(),
        taxCredit: _taxCreditSettings(),
        year: widget.year,
        month: widget.month,
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

  /// 登録後、一度も実績の残債を入れていない（起点が「借入額・ローン開始月」のまま）か。
  /// その場合は借入額やローン開始日を直したときに、残債の起点も合わせて直す。
  bool _loanAnchorIsStillInitial(Map<String, dynamic> d) {
    final asOf = DateTime.tryParse(d['loan_balance_as_of'] as String? ?? '');
    final start = DateTime.tryParse(d['loan_start_date'] as String? ?? '');
    if (asOf == null || start == null) return false;
    final sameMonth = asOf.year == start.year && asOf.month == start.month;
    final balance = (d['current_loan_balance'] as num?)?.toInt();
    final original = (d['original_loan_amount'] as num?)?.toInt();
    return sameMonth && balance == original;
  }

  Future<void> _saveEdit(String name) async {
    final purchasePrice = _toInt(_purchasePriceCtrl);
    if (purchasePrice == 0) {
      showMissingFieldDialog(context, '取得価格を入力してください。');
      return;
    }
    final shareNum = _toInt(_shareNumCtrl);
    final shareDen = _toInt(_shareDenCtrl);
    if (shareNum <= 0 || shareDen <= 0 || shareNum > shareDen) {
      showMissingFieldDialog(context, '持分を正しく入力してください（例: 1 / 2）。');
      return;
    }
    final d = widget.initialDetails ?? {};
    final termYears = int.tryParse(_loanTermYearsCtrl.text);

    setState(() => _saving = true);
    try {
      await _repository.updateRealEstateInfo(
        assetId: widget.editAssetId!,
        name: name,
        acquisitionDate: _acquisitionDate.toIso8601String().substring(0, 10),
        purchasePrice: purchasePrice,
        landPrice: _toInt(_landPriceCtrl),
        buildingPrice: _toInt(_buildingPriceCtrl),
        capitalizedInitialCosts: _toInt(_initialCostsCtrl),
        ownershipShareNumerator: shareNum,
        ownershipShareDenominator: shareDen,
        downPayment: _toInt(_downPaymentCtrl),
        originalLoanAmount: _toInt(_loanAmountCtrl),
        loanStartDate: _loanStartDate.toIso8601String().substring(0, 10),
        loanTermMonths: termYears != null && termYears > 0
            ? termYears * 12
            : (d['loan_term_months'] as num?)?.toInt() ?? 0,
        resetLoanAnchor: _loanAnchorIsStillInitial(d),
        otherInitialCosts: _toInt(_otherCostsTotalCtrl),
        otherInitialCostsMemo: _otherCostsMemoCtrl.text.trim(),
        taxCredit: _taxCreditSettings(),
      );
      if (!mounted) return;
      Navigator.pop(context, name);
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
    final cardColor = context.colors.surface;
    final dividerColor =
        context.colors.separator;
    final labelColor =
        context.colors.secondaryLabel;
    final hintColor =
        context.colors.tertiaryLabel;
    final sectionColor =
        context.colors.secondaryLabel;
    final subItems = _childCategories[_selectedC1Id] ?? [];

    Widget buildCard(List<Widget> rows) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: AppRadius.mdAll,
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
                    fontSize: AppFont.caption1,
                    fontWeight: AppFont.medium,
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
                style: TextStyle(fontSize: AppFont.body, color: hintColor)),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: isDecimal),
              inputFormatters: isDecimal
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: AppFont.body),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: TextStyle(color: hintColor, fontSize: AppFont.body),
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
                    style: const TextStyle(fontSize: AppFont.body)),
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
                fontSize: AppFont.footnote,
                fontWeight: AppFont.semibold,
                color: sectionColor)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          widget.isEdit ? '物件情報を編集' : '不動産を追加',
          style:
              theme.textTheme.titleLarge!.copyWith(fontWeight: AppFont.semibold),
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
            if (!widget.isEdit)
            buildRow(
              'カテゴリ',
              SizedBox(
                height: 22,
                child: DropdownButton<String>(
                  value: _selectedC1Id,
                  hint: Text('選択してください',
                      style: TextStyle(color: hintColor, fontSize: AppFont.body)),
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  style: TextStyle(
                      fontSize: AppFont.body, color: theme.colorScheme.onSurface),
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
            if (!widget.isEdit && _selectedC1Id != null)
              buildRow(
                'サブカテゴリ',
                SizedBox(
                  height: 22,
                  child: DropdownButton<String>(
                    value: _selectedC2Id,
                    hint: Text('なし',
                        style: TextStyle(color: hintColor, fontSize: AppFont.body)),
                    underline: const SizedBox.shrink(),
                    isExpanded: true,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    style: TextStyle(
                        fontSize: AppFont.body, color: theme.colorScheme.onSurface),
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

          // ── 持分・取得原価 ────────────────────────────────────
          buildSection('持分・取得原価'),
          buildCard([
            buildRow(
              '自分の持分（登記上）',
              Row(
                children: [
                  Expanded(child: buildTextField(_shareNumCtrl, hint: '1')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('/',
                        style: TextStyle(
                            fontSize: AppFont.body, color: hintColor)),
                  ),
                  Expanded(child: buildTextField(_shareDenCtrl, hint: '1')),
                ],
              ),
            ),
            buildRow('取得価格（物件全体）',
                buildTextField(_purchasePriceCtrl, hint: '例: 45000000', prefix: '¥')),
            buildRow('うち土地',
                buildTextField(_landPriceCtrl, hint: '例: 15000000', prefix: '¥')),
            buildRow('うち建物',
                buildTextField(_buildingPriceCtrl, hint: '例: 30000000', prefix: '¥')),
            buildRow('初期費用（自分が払った分）',
                buildTextField(_initialCostsCtrl, hint: '例: 1500000', prefix: '¥')),
            buildRow('その他の諸費用（取得原価に入れない分）',
                buildTextField(_otherCostsTotalCtrl, hint: '例: 1200000', prefix: '¥')),
            buildRow(
              'その他の諸費用の内訳メモ',
              TextField(
                controller: _otherCostsMemoCtrl,
                maxLines: null,
                style: const TextStyle(fontSize: AppFont.body),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '例: ローン手数料、抵当権設定登記、修繕積立基金、延長保証',
                  hintStyle:
                      TextStyle(color: hintColor, fontSize: AppFont.body),
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              '初期費用には仲介手数料・登記費用・不動産取得税・印紙税を入れます。'
              'ローン手数料・修繕積立基金・延長保証などは「その他の諸費用」に記録します'
              '（記録用で、取得原価や純資産には入りません）。\n'
              '土地・建物の内訳は売買契約書の金額を入れます（簿価の計算に使います）。',
              style: TextStyle(fontSize: AppFont.caption1, color: sectionColor),
            ),
          ),

          // ── ローン情報 ────────────────────────────────────────
          buildSection('自分のローン'),
          buildCard([
            buildRow('頭金（自分が出した分）',
                buildTextField(_downPaymentCtrl, hint: '例: 5000000', prefix: '¥')),
            buildRow('借入額',
                buildTextField(_loanAmountCtrl, hint: '例: 40000000', prefix: '¥')),
            buildDateRow('ローン開始日', _loanStartDate,
                () => _pickDate(isAcquisition: false)),
            buildRow('返済期間（年）',
                buildTextField(_loanTermYearsCtrl, hint: '例: 35')),
            if (!widget.isEdit) ...[
              buildRow('現在の金利（%）',
                  buildTextField(_interestRateCtrl, hint: '例: 0.475', isDecimal: true)),
              buildRow('月々返済額',
                  buildTextField(_monthlyPaymentCtrl, hint: '例: 100000', prefix: '¥')),
            ],
          ]),
          if (widget.isEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                '推定価値・金利・返済額・残債・月次コストは「月次更新」で変更します。',
                style: TextStyle(fontSize: AppFont.caption1, color: sectionColor),
              ),
            ),

          // ── 住宅ローン控除 ────────────────────────────────────
          buildSection('住宅ローン控除'),
          buildCard([
            buildRow('入居年',
                buildTextField(_tcMoveInYearCtrl, hint: '例: 2026（空なら計算しない）')),
            buildRow('控除率（%）',
                buildTextField(_tcRateCtrl, hint: '0.7', isDecimal: true)),
            buildRow('控除期間（年）',
                buildTextField(_tcYearsCtrl, hint: '13')),
            buildRow('借入限度額（自分の分）',
                buildTextField(_tcLoanLimitCtrl, hint: '空なら上限なし', prefix: '¥')),
            buildRow('1年の控除の上限（所得税＋住民税）',
                buildTextField(_tcAnnualCapCtrl, hint: '空なら上限なし', prefix: '¥')),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              '控除率・期間・借入限度額は入居年と住宅の性能で変わります。'
              '不動産会社の資料や国税庁のサイトで確認して入力してください。',
              style: TextStyle(fontSize: AppFont.caption1, color: sectionColor),
            ),
          ),

          if (!widget.isEdit) ...[
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
              style: TextStyle(fontSize: AppFont.caption1, color: sectionColor),
            ),
          ),

          // ── 現在の状態 ────────────────────────────────────────
          buildSection('現在の状態'),
          buildCard([
            buildRow('現在の推定価値（物件全体）',
                buildTextField(_estimatedValueCtrl, hint: '例: 46000000', prefix: '¥')),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              '正味の持ち分 = 推定価値 × 持分 − 自分の残債。'
              '残債は借入額・ローン開始日・金利・月々返済額から毎月自動で計算します。',
              style: TextStyle(fontSize: AppFont.caption1, color: sectionColor),
            ),
          ),
          ],

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
                : const Text('保存', style: TextStyle(fontSize: AppFont.callout)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
