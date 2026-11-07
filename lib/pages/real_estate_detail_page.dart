import 'package:asset_note/pages/real_estate_edit_page.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealEstateDetailPage extends StatefulWidget {
  const RealEstateDetailPage({
    super.key,
    required this.assetId,
    required this.assetName,
  });

  final int assetId;
  final String assetName;

  @override
  State<RealEstateDetailPage> createState() => _RealEstateDetailPageState();
}

class _RealEstateDetailPageState extends State<RealEstateDetailPage> {
  late final AssetsRepository _repository;
  Map<String, dynamic>? _details;
  bool _loading = true;
  final _fmt = NumberFormat('#,###', 'ja_JP');

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _repository.fetchRealEstateDetails(widget.assetId);
    if (!mounted) return;
    setState(() {
      _details = d;
      _loading = false;
    });
  }

  int _elapsedMonths(String acquisitionDate) {
    try {
      final acq = DateTime.parse(acquisitionDate);
      final now = DateTime.now();
      return (now.year - acq.year) * 12 + (now.month - acq.month);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_details == null) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: const Center(child: Text('データが見つかりません。')),
      );
    }

    final d = _details!;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final dividerColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    final labelColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final sectionColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6D6D72);

    // ── データ取得 ────────────────────────────────────────────
    final estimatedValue = (d['estimated_value'] as num?)?.toInt() ?? 0;
    final currentBalance = (d['current_loan_balance'] as num?)?.toInt() ?? 0;
    final netEquity = estimatedValue - currentBalance;
    final purchasePrice = (d['purchase_price'] as num?)?.toInt() ?? 0;
    final originalLoan = (d['original_loan_amount'] as num?)?.toInt() ?? 0;
    final loanTermMonths = (d['loan_term_months'] as num?)?.toInt() ?? 0;
    final interestRate =
        (d['interest_rate_percent'] as num?)?.toDouble() ?? 0.0;

    final monthlyPayment = (d['monthly_payment'] as num?)?.toInt() ?? 0;
    final managementFee = (d['management_fee'] as num?)?.toInt() ?? 0;
    final repairReserve = (d['repair_reserve_fund'] as num?)?.toInt() ?? 0;
    final propertyTax = (d['property_tax_monthly'] as num?)?.toInt() ?? 0;
    final otherCosts = (d['other_monthly_costs'] as num?)?.toInt() ?? 0;
    final virtualRent = (d['virtual_monthly_rent'] as num?)?.toInt() ?? 0;
    final acquisitionDate = d['acquisition_date'] as String? ?? '';

    final totalMonthlyCost =
        monthlyPayment + managementFee + repairReserve + propertyTax + otherCosts;
    final monthlySavings = virtualRent - totalMonthlyCost;
    final elapsed = _elapsedMonths(acquisitionDate);
    final cumulativeSavings = monthlySavings * elapsed;
    final unrealizedGain = estimatedValue - purchasePrice;
    final totalBenefit = cumulativeSavings + unrealizedGain;

    // ── UI ヘルパー ───────────────────────────────────────────
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

    Widget buildRow(String label, String value, {Color? valueColor, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 15, color: labelColor)),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
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

    Color signColor(int v) =>
        v >= 0 ? const Color(0xFF00963C) : const Color(0xFFDC1E32);
    String signedAmount(int v) =>
        '${v >= 0 ? '+' : ''}¥${_fmt.format(v)}';

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── 資産価値 ──────────────────────────────────────────
          buildSection('資産価値'),
          buildCard([
            buildRow('現在の推定価値', '¥${_fmt.format(estimatedValue)}'),
            buildRow('ローン残債', '¥${_fmt.format(currentBalance)}'),
            buildRow(
              '純資産',
              '¥${_fmt.format(netEquity)}',
              valueColor: netEquity >= 0
                  ? theme.colorScheme.primary
                  : const Color(0xFFDC1E32),
              bold: true,
            ),
          ]),

          // ── 賃貸 vs 持ち家 ────────────────────────────────────
          buildSection('賃貸 vs 持ち家'),
          buildCard([
            buildRow('実質月コスト', '¥${_fmt.format(totalMonthlyCost)}'),
            buildRow('仮想家賃', '¥${_fmt.format(virtualRent)}'),
            buildRow(
              '月々の差額',
              signedAmount(monthlySavings),
              valueColor: signColor(monthlySavings),
            ),
            buildRow(
              '累積節約額（$elapsed ヶ月）',
              signedAmount(cumulativeSavings),
              valueColor: signColor(cumulativeSavings),
            ),
            buildRow(
              '含み益/損',
              signedAmount(unrealizedGain),
              valueColor: signColor(unrealizedGain),
            ),
            buildRow(
              'トータルメリット',
              signedAmount(totalBenefit),
              valueColor: signColor(totalBenefit),
              bold: true,
            ),
          ]),

          // ── 月次コスト内訳 ────────────────────────────────────
          buildSection('月次コスト内訳'),
          buildCard([
            buildRow('ローン返済額', '¥${_fmt.format(monthlyPayment)}'),
            buildRow('管理費', '¥${_fmt.format(managementFee)}'),
            buildRow('修繕積立金', '¥${_fmt.format(repairReserve)}'),
            buildRow('固定資産税（月換算）', '¥${_fmt.format(propertyTax)}'),
            if (otherCosts > 0)
              buildRow('その他', '¥${_fmt.format(otherCosts)}'),
            buildRow(
              '合計',
              '¥${_fmt.format(totalMonthlyCost)}',
              valueColor: theme.colorScheme.primary,
              bold: true,
            ),
          ]),

          // ── ローン情報 ────────────────────────────────────────
          buildSection('ローン情報'),
          buildCard([
            buildRow('取得価格', '¥${_fmt.format(purchasePrice)}'),
            buildRow('当初借入額', '¥${_fmt.format(originalLoan)}'),
            buildRow('現在の金利', '${interestRate.toStringAsFixed(3)}%'),
            if (loanTermMonths > 0)
              buildRow('返済期間', '${(loanTermMonths / 12).round()}年'),
            if (acquisitionDate.isNotEmpty)
              buildRow('取得日', acquisitionDate.replaceAll('-', '/')),
          ]),

          const SizedBox(height: 32),
          FilledButton(
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => RealEstateEditPage(
                    assetId: widget.assetId,
                    details: Map<String, dynamic>.from(d),
                  ),
                ),
              );
              if (updated == true) await _load();
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: const StadiumBorder(),
            ),
            child: const Text('月次更新', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Text(
        widget.assetName,
        style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.dividerColor),
      ),
    );
  }
}
