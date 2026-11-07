import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealEstateEditPage extends StatefulWidget {
  const RealEstateEditPage({
    super.key,
    required this.assetId,
    required this.details,
  });

  final int assetId;
  final Map<String, dynamic> details;

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

    final oldBalance = (d['current_loan_balance'] as num?)?.toInt() ?? 0;
    final rate = (d['interest_rate_percent'] as num?)?.toDouble() ?? 0.0;
    final payment = (d['monthly_payment'] as num?)?.toInt() ?? 0;

    // 元利均等での残債自動計算
    final monthlyRate = rate / 100.0 / 12.0;
    final interest = monthlyRate > 0 ? (oldBalance * monthlyRate).round() : 0;
    final principal = payment - interest;
    final autoBalance = (oldBalance - principal).clamp(0, oldBalance);

    _balanceHelperText =
        '前月: ¥${_fmt.format(oldBalance)}  '
        '元金: ¥${_fmt.format(principal)}  '
        '→ 自動計算: ¥${_fmt.format(autoBalance)}';

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
      bool isDecimal = false,
      String? prefix,
    }) {
      return Row(
        children: [
          if (prefix != null)
            Text(prefix, style: TextStyle(fontSize: 17, color: hintColor)),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: isDecimal),
              inputFormatters: isDecimal
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 17),
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
          '月次更新',
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
          // ── 資産価値 ──────────────────────────────────────────
          buildSection('資産価値'),
          buildCard([
            buildRow('現在の推定価値',
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
                    style: TextStyle(fontSize: 11, color: sectionColor),
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
                : const Text('保存', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
