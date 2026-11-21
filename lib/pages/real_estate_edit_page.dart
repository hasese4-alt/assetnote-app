import 'package:asset_note/theme/app_tokens.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/real_estate_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealEstateEditPage extends StatefulWidget {
  const RealEstateEditPage({
    super.key,
    required this.assetId,
    required this.details,
    required this.year,
    required this.month,
  });

  final int assetId;
  final Map<String, dynamic> details;

  /// 更新する月（資産一覧の編集中の月）
  final int year;
  final int month;

  @override
  State<RealEstateEditPage> createState() => _RealEstateEditPageState();
}

class _RealEstateEditPageState extends State<RealEstateEditPage> {
  late final AssetsRepository _repository;

  late final TextEditingController _estimatedValueCtrl;
  late final TextEditingController _interestRateCtrl;
  late final TextEditingController _monthlyPaymentCtrl;
  late final TextEditingController _loanBalanceCtrl;
  late final TextEditingController _managementFeeCtrl;
  late final TextEditingController _repairReserveCtrl;
  late final TextEditingController _propertyTaxCtrl;
  late final TextEditingController _otherCostsCtrl;
  late final TextEditingController _virtualRentCtrl;

  bool _saving = false;
  late final String _balanceHelperText;
  final _fmt = NumberFormat('#,###', 'ja_JP');

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    final d = widget.details;

    // 前回記録した残債（起点）から、この月の返済後の残債を自動計算する
    final savedBalance = (d['current_loan_balance'] as num?)?.toInt() ?? 0;
    final anchor = DateTime.tryParse(d['loan_balance_as_of'] as String? ?? '');
    final autoBalance = RealEstateMath.balanceFromDetails(
        d, year: widget.year, month: widget.month);

    _balanceHelperText = anchor == null
        ? '前回の記録: ¥${_fmt.format(savedBalance)}'
        : '前回の記録: ¥${_fmt.format(savedBalance)}'
            '（${anchor.year}年${anchor.month}月の返済後）\n'
            '→ ${widget.year}年${widget.month}月の返済後（自動計算）: '
            '¥${_fmt.format(autoBalance)}\n'
            '実際の残高と違うときは書き換えてください。';

    _estimatedValueCtrl = TextEditingController(
        text: ((d['estimated_value'] as num?)?.toInt() ?? 0).toString());
    _interestRateCtrl = TextEditingController(
        text: (d['interest_rate_percent'] as num?)?.toDouble().toString() ?? '0');
    _monthlyPaymentCtrl = TextEditingController(
        text: ((d['monthly_payment'] as num?)?.toInt() ?? 0).toString());
    _loanBalanceCtrl =
        TextEditingController(text: autoBalance.toString());
    _managementFeeCtrl = TextEditingController(
        text: ((d['management_fee'] as num?)?.toInt() ?? 0).toString());
    _repairReserveCtrl = TextEditingController(
        text: ((d['repair_reserve_fund'] as num?)?.toInt() ?? 0).toString());
    _propertyTaxCtrl = TextEditingController(
        text: ((d['property_tax_monthly'] as num?)?.toInt() ?? 0).toString());
    _otherCostsCtrl = TextEditingController(
        text: ((d['other_monthly_costs'] as num?)?.toInt() ?? 0).toString());
    _virtualRentCtrl = TextEditingController(
        text: ((d['virtual_monthly_rent'] as num?)?.toInt() ?? 0).toString());
  }

  @override
  void dispose() {
    _estimatedValueCtrl.dispose();
    _interestRateCtrl.dispose();
    _monthlyPaymentCtrl.dispose();
    _loanBalanceCtrl.dispose();
    _managementFeeCtrl.dispose();
    _repairReserveCtrl.dispose();
    _propertyTaxCtrl.dispose();
    _otherCostsCtrl.dispose();
    _virtualRentCtrl.dispose();
    super.dispose();
  }

  int _toInt(TextEditingController ctrl) =>
      int.tryParse(ctrl.text.replaceAll(',', '').replaceAll('¥', '')) ?? 0;

  double _toDouble(TextEditingController ctrl) =>
      double.tryParse(ctrl.text) ?? 0.0;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updateRealEstateDetails(
        assetId: widget.assetId,
        year: widget.year,
        month: widget.month,
        estimatedValue: _toInt(_estimatedValueCtrl),
        currentLoanBalance: _toInt(_loanBalanceCtrl),
        interestRatePercent: _toDouble(_interestRateCtrl),
        monthlyPayment: _toInt(_monthlyPaymentCtrl),
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
    final cardColor = context.colors.surface;
    final dividerColor =
        context.colors.separator;
    final labelColor =
        context.colors.secondaryLabel;
    final hintColor =
        context.colors.tertiaryLabel;
    final sectionColor =
        context.colors.secondaryLabel;

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
      bool isDecimal = false,
      String? prefix,
    }) {
      return Row(
        children: [
          if (prefix != null)
            Text(prefix, style: TextStyle(fontSize: AppFont.body, color: hintColor)),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: isDecimal),
              inputFormatters: isDecimal
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: AppFont.body),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
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
          '月次更新（${widget.year}年${widget.month}月）',
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
          // ── 資産価値 ──────────────────────────────────────────
          buildSection('資産価値'),
          buildCard([
            buildRow('現在の推定価値（物件全体）',
                buildTextField(_estimatedValueCtrl, prefix: '¥')),
          ]),

          // ── ローン ────────────────────────────────────────────
          buildSection('ローン'),
          buildCard([
            buildRow('現在の金利（%）',
                buildTextField(_interestRateCtrl, isDecimal: true)),
            buildRow('月々返済額',
                buildTextField(_monthlyPaymentCtrl, prefix: '¥')),
            buildRow(
              'ローン残債',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTextField(_loanBalanceCtrl, prefix: '¥'),
                  const SizedBox(height: 4),
                  Text(
                    _balanceHelperText,
                    style: TextStyle(fontSize: AppFont.caption2, color: sectionColor),
                  ),
                ],
              ),
            ),
          ]),

          // ── 月次コスト ────────────────────────────────────────
          buildSection('月次コスト（月額）'),
          buildCard([
            buildRow('管理費',
                buildTextField(_managementFeeCtrl, prefix: '¥')),
            buildRow('修繕積立金',
                buildTextField(_repairReserveCtrl, prefix: '¥')),
            buildRow('固定資産税（月換算）',
                buildTextField(_propertyTaxCtrl, prefix: '¥')),
            buildRow('その他',
                buildTextField(_otherCostsCtrl, prefix: '¥')),
          ]),

          // ── 賃貸比較 ──────────────────────────────────────────
          buildSection('賃貸比較'),
          buildCard([
            buildRow('仮想家賃',
                buildTextField(_virtualRentCtrl, prefix: '¥')),
          ]),

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
