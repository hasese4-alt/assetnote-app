import 'package:asset_note/utils/yen_format.dart';
import 'package:asset_note/theme/app_tokens.dart';
import 'package:asset_note/pages/real_estate_add_page.dart';
import 'package:asset_note/pages/real_estate_edit_page.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/real_estate_math.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealEstateDetailPage extends StatefulWidget {
  const RealEstateDetailPage({
    super.key,
    required this.assetId,
    required this.assetName,
    required this.year,
    required this.month,
  });

  final int assetId;
  final String assetName;

  /// 表示する月（資産一覧の編集中の月）。ローン残債はこの月の返済後で計算する。
  final int year;
  final int month;

  @override
  State<RealEstateDetailPage> createState() => _RealEstateDetailPageState();
}

class _RealEstateDetailPageState extends State<RealEstateDetailPage> {
  late final AssetsRepository _repository;
  Map<String, dynamic>? _details;
  bool _loading = true;
  late String _assetName = widget.assetName;
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

  Future<void> _openInfoEdit() async {
    final details = _details;
    if (details == null) return;
    final newName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RealEstateAddPage.edit(
          assetId: widget.assetId,
          initialName: _assetName,
          initialDetails: Map<String, dynamic>.from(details),
        ),
      ),
    );
    if (newName == null || !mounted) return;
    setState(() => _assetName = newName);
    await _load();
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
    final cardColor = context.colors.surface;
    final dividerColor =
        context.colors.separator;
    final labelColor =
        context.colors.secondaryLabel;
    final sectionColor =
        context.colors.secondaryLabel;

    // ── データ取得 ────────────────────────────────────────────
    int intOf(String key, [int fallback = 0]) =>
        (d[key] as num?)?.toInt() ?? fallback;

    final estimatedValue = intOf('estimated_value');
    final currentBalance = RealEstateMath.balanceFromDetails(
        d, year: widget.year, month: widget.month);
    final purchasePrice = intOf('purchase_price');
    final shareNum = intOf('ownership_share_numerator', 1);
    final shareDen = intOf('ownership_share_denominator', 1);
    final share = RealEstateMath.shareRatio(shareNum, shareDen);
    final isSoleOwner = share >= 1.0;
    final landPrice = intOf('land_price');
    final buildingPrice = intOf('building_price');
    final initialCosts = intOf('capitalized_initial_costs');
    final otherInitialCosts = intOf('other_initial_costs');
    final otherInitialCostsMemo = d['other_initial_costs_memo'] as String? ?? '';

    final ownValue = RealEstateMath.ownMarketValue(estimatedValue, share);
    final netEquity = RealEstateMath.netEquity(ownValue, currentBalance);
    final ownPurchase = (purchasePrice * share).round();
    final costBasis = RealEstateMath.ownCostBasis(
      purchasePrice: purchasePrice,
      share: share,
      capitalizedInitialCosts: initialCosts,
    );
    final acquired = DateTime.tryParse(d['acquisition_date'] as String? ?? '');
    final bookValue = acquired == null
        ? null
        : RealEstateMath.ownBookValue(
            purchasePrice: purchasePrice,
            landPrice: landPrice,
            buildingPrice: buildingPrice,
            share: share,
            capitalizedInitialCosts: initialCosts,
            acquisitionDate: acquired,
            asOf: DateTime.now(),
          );
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
    // 住宅ローン控除（表示中の年以降の見込み）
    final taxCredits =
        RealEstateMath.taxCreditSchedule(d, fromYear: widget.year);
    final thisYearCredit = taxCredits.isNotEmpty &&
            taxCredits.first.year == widget.year
        ? taxCredits.first.credit
        : 0;
    final remainingCreditTotal =
        taxCredits.fold<int>(0, (sum, e) => sum + e.credit);
    final hasTaxCredit = (d['tax_credit_move_in_year'] as num?) != null;
    final monthlyCredit = thisYearCredit ~/ 12;

    final monthlySavings = virtualRent - totalMonthlyCost + monthlyCredit;
    final elapsed = _elapsedMonths(acquisitionDate);
    final cumulativeSavings = monthlySavings * elapsed;
    final unrealizedGain = ownValue - costBasis;
    final totalBenefit = cumulativeSavings + unrealizedGain;
    final paymentSplit = RealEstateMath.splitPayment(
      loanBalance: currentBalance,
      interestRatePercent: interestRate,
      monthlyPayment: monthlyPayment,
    );

    // ── UI ヘルパー ───────────────────────────────────────────
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

    Widget buildRow(String label, String value, {Color? valueColor, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: AppFont.subheadline, color: labelColor)),
            Text(
              value,
              style: TextStyle(
                fontSize: AppFont.subheadline,
                fontWeight: bold ? AppFont.bold : AppFont.semibold,
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
                fontSize: AppFont.footnote,
                fontWeight: AppFont.semibold,
                color: sectionColor)),
      );
    }

    Color signColor(int v) =>
        v >= 0 ? context.colors.positive : context.colors.negative;
    String signedAmount(int v) =>
        formatYen(v, signed: true);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── 資産価値 ──────────────────────────────────────────
          buildSection('資産価値'),
          buildCard([
            buildRow(
                isSoleOwner ? '現在の推定価値' : '現在の推定価値（物件全体）',
                '¥${_fmt.format(estimatedValue)}'),
            if (!isSoleOwner) ...[
              buildRow('自分の持分', '$shareNum / $shareDen'),
              buildRow('自分の評価額', '¥${_fmt.format(ownValue)}'),
            ],
            buildRow('自分のローン残債（${widget.month}月の返済後）',
                '¥${_fmt.format(currentBalance)}'),
            buildRow(
              '正味の持ち分',
              '¥${_fmt.format(netEquity)}',
              valueColor: netEquity >= 0
                  ? theme.colorScheme.primary
                  : context.colors.negative,
              bold: true,
            ),
          ]),

          // ── 取得原価・簿価 ────────────────────────────────────
          buildSection('取得原価・簿価'),
          buildCard([
            buildRow(
                isSoleOwner ? '取得価格' : '取得価格（自分の持分）',
                '¥${_fmt.format(ownPurchase)}'),
            buildRow('初期費用（取得原価分）', '¥${_fmt.format(initialCosts)}'),
            buildRow('自分の取得原価', '¥${_fmt.format(costBasis)}', bold: true),
            if (otherInitialCosts > 0) ...[
              buildRow('その他の諸費用（記録用）',
                  '¥${_fmt.format(otherInitialCosts)}'),
              buildRow('購入時に払った総額',
                  '¥${_fmt.format(costBasis + otherInitialCosts)}'),
            ],
            buildRow(
              '含み損益',
              signedAmount(unrealizedGain),
              valueColor: signColor(unrealizedGain),
            ),
            buildRow(
              '簿価',
              bookValue == null ? '—' : '¥${_fmt.format(bookValue)}',
            ),
            if (bookValue != null)
              buildRow(
                '時価 − 簿価',
                signedAmount(ownValue - bookValue),
                valueColor: signColor(ownValue - bookValue),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              bookValue == null
                  ? '土地・建物の内訳を入力すると簿価を計算します。'
                  : '簿価は自宅用の鉄筋コンクリート造（耐用年数70年）として建物を減価償却した値です。',
              style: TextStyle(fontSize: AppFont.caption1, color: sectionColor),
            ),
          ),
          if (otherInitialCostsMemo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                'その他の諸費用の内訳: $otherInitialCostsMemo',
                style:
                    TextStyle(fontSize: AppFont.caption1, color: sectionColor),
              ),
            ),

          // ── 賃貸 vs 持ち家 ────────────────────────────────────
          buildSection('賃貸 vs 持ち家'),
          buildCard([
            buildRow('実質月コスト', '¥${_fmt.format(totalMonthlyCost)}'),
            if (monthlyCredit > 0)
              buildRow('住宅ローン控除（月換算）',
                  signedAmount(monthlyCredit),
                  valueColor: context.colors.positive),
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

          // ── 住宅ローン控除 ────────────────────────────────────
          if (hasTaxCredit) ...[
            buildSection('住宅ローン控除（見込み）'),
            buildCard([
              buildRow('${widget.year}年の控除見込み',
                  '¥${_fmt.format(thisYearCredit)}'),
              buildRow('控除の残り年数', '${taxCredits.length}年'),
              buildRow('残り期間の控除見込み合計',
                  '¥${_fmt.format(remainingCreditTotal)}',
                  bold: true),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                '各年の年末残高（自動計算）× 控除率で計算した見込みです。'
                '控除されたお金は口座に入るので、純資産には足していません。',
                style:
                    TextStyle(fontSize: AppFont.caption1, color: sectionColor),
              ),
            ),
          ],

          // ── 月次コスト内訳 ────────────────────────────────────
          buildSection('月次コスト内訳'),
          buildCard([
            buildRow('ローン返済額', '¥${_fmt.format(monthlyPayment)}'),
            if (monthlyPayment > 0) ...[
              buildRow('　うち元本（持ち分に移る）',
                  '¥${_fmt.format(paymentSplit.principal)}'),
              buildRow('　うち利息', '¥${_fmt.format(paymentSplit.interest)}'),
            ],
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
                    year: widget.year,
                    month: widget.month,
                  ),
                ),
              );
              if (updated == true) await _load();
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: const StadiumBorder(),
            ),
            child: const Text('月次更新', style: TextStyle(fontSize: AppFont.callout)),
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
      actions: [
        if (_details != null)
          IconButton(
            tooltip: '物件情報を編集',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openInfoEdit,
          ),
      ],
      title: Text(
        _assetName,
        style: theme.textTheme.titleLarge!.copyWith(fontWeight: AppFont.semibold),
        overflow: TextOverflow.ellipsis,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.dividerColor),
      ),
    );
  }
}
