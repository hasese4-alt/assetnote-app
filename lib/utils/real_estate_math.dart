/// 自宅（マンション）の評価・取得原価・簿価・ローン返済内訳の計算。
///
/// 金額は物件全体の値で保存し、自分の分は持分を掛けて計算する。
/// 簿価は「自宅用（非業務用）の鉄筋コンクリート造」として計算する。
class RealEstateMath {
  RealEstateMath._();

  /// 非業務用の耐用年数（鉄筋コンクリート造 47年 × 1.5）
  static const int buildingUsefulLifeYears = 70;

  /// 耐用年数70年の定額法償却率
  static const double depreciationRate = 0.015;

  /// 建物の償却は取得価額の95%まで
  static const double minBuildingRemainingRatio = 0.05;

  /// 持分（分子/分母）を 0〜1 の割合にする。不正な値は 1（単独所有）とみなす。
  static double shareRatio(int numerator, int denominator) {
    if (denominator <= 0 || numerator <= 0) return 1.0;
    final r = numerator / denominator;
    return r > 1.0 ? 1.0 : r;
  }

  /// 自分の評価額 = 物件全体の時価 × 持分
  static int ownMarketValue(int estimatedValue, double share) =>
      (estimatedValue * share).round();

  /// 正味の持ち分 = 自分の評価額 − 自分のローン残高
  static int netEquity(int ownMarketValue, int loanBalance) =>
      ownMarketValue - loanBalance;

  /// 自分の取得原価 = 物件価格 × 持分 + 自分が払った初期費用（取得原価に入れる分）
  static int ownCostBasis({
    required int purchasePrice,
    required double share,
    required int capitalizedInitialCosts,
  }) =>
      (purchasePrice * share).round() + capitalizedInitialCosts;

  /// 減価償却の経過年数。6か月以上は1年に切り上げ、6か月未満は切り捨てる。
  static int elapsedYears(DateTime acquisitionDate, DateTime asOf) {
    var months = (asOf.year - acquisitionDate.year) * 12 +
        (asOf.month - acquisitionDate.month);
    if (asOf.day < acquisitionDate.day) months -= 1;
    if (months <= 0) return 0;
    final years = months ~/ 12;
    return months % 12 >= 6 ? years + 1 : years;
  }

  /// 自分の簿価。土地・建物の内訳が未入力なら null。
  ///
  /// 土地・建物の内訳は比率として使い、物件価格に掛ける。
  /// 初期費用も同じ比率で土地と建物に振り分ける。
  static int? ownBookValue({
    required int purchasePrice,
    required int landPrice,
    required int buildingPrice,
    required double share,
    required int capitalizedInitialCosts,
    required DateTime acquisitionDate,
    required DateTime asOf,
  }) {
    final total = landPrice + buildingPrice;
    if (total <= 0 || purchasePrice <= 0) return null;
    final landRatio = landPrice / total;
    final buildingRatio = buildingPrice / total;

    final ownLand = purchasePrice * share * landRatio +
        capitalizedInitialCosts * landRatio;
    final ownBuilding = purchasePrice * share * buildingRatio +
        capitalizedInitialCosts * buildingRatio;

    final years = elapsedYears(acquisitionDate, asOf);
    final depreciation = ownBuilding * 0.9 * depreciationRate * years;
    final floor = ownBuilding * minBuildingRemainingRatio;
    final remaining = ownBuilding - depreciation;
    final building = remaining < floor ? floor : remaining;

    return (ownLand + building).round();
  }

  /// 起点の残高から、指定した月の返済後の残高を計算する。
  ///
  /// [anchorBalance] は [anchorMonth] の返済が済んだ後の残高。
  /// 起点の月より後の月ごとに、今の金利と返済額で元本を引いていく。
  /// [asOf] が起点の月以前なら、起点の残高をそのまま返す。
  static int projectedBalance({
    required int anchorBalance,
    required DateTime anchorMonth,
    required DateTime asOf,
    required double interestRatePercent,
    required int monthlyPayment,
  }) {
    final months = (asOf.year - anchorMonth.year) * 12 +
        (asOf.month - anchorMonth.month);
    var balance = anchorBalance;
    for (var i = 0; i < months && balance > 0; i++) {
      balance -= splitPayment(
        loanBalance: balance,
        interestRatePercent: interestRatePercent,
        monthlyPayment: monthlyPayment,
      ).principal;
    }
    return balance;
  }

  /// real_estate_details の1行から、[year]/[month] の返済後の残高を計算する。
  /// 起点の月（loan_balance_as_of）が無い行は、保存されている残高をそのまま返す。
  static int balanceFromDetails(
    Map<String, dynamic> d, {
    required int year,
    required int month,
  }) {
    final saved = (d['current_loan_balance'] as num?)?.toInt() ?? 0;
    final asOf = DateTime.tryParse(d['loan_balance_as_of'] as String? ?? '');
    if (asOf == null) return saved;
    return projectedBalance(
      anchorBalance: saved,
      anchorMonth: asOf,
      asOf: DateTime(year, month),
      interestRatePercent:
          (d['interest_rate_percent'] as num?)?.toDouble() ?? 0.0,
      monthlyPayment: (d['monthly_payment'] as num?)?.toInt() ?? 0,
    );
  }

  /// 住宅ローン控除の1年分の見込み額。
  ///
  /// 年末残高（借入限度額が 1 以上ならそれが上限）× 控除率。100円未満は切り捨て。
  /// [annualCap] が 1 以上なら、その額（所得税＋住民税から引ける上限）までにする。
  static int annualTaxCredit({
    required int yearEndBalance,
    required double ratePercent,
    int loanLimit = 0,
    int annualCap = 0,
  }) {
    if (yearEndBalance <= 0 || ratePercent <= 0) return 0;
    final base =
        loanLimit > 0 && yearEndBalance > loanLimit ? loanLimit : yearEndBalance;
    var credit = (base * ratePercent / 100).floor() ~/ 100 * 100;
    if (annualCap > 0 && credit > annualCap) credit = annualCap;
    return credit;
  }

  /// real_estate_details の1行から、[fromYear] 以降の控除の見込みを年ごとに出す。
  /// 入居年が未設定なら空。控除期間が終わった年は含めない。
  static List<({int year, int credit})> taxCreditSchedule(
    Map<String, dynamic> d, {
    required int fromYear,
  }) {
    final moveIn = (d['tax_credit_move_in_year'] as num?)?.toInt();
    if (moveIn == null || moveIn <= 0) return const [];
    final years = (d['tax_credit_years'] as num?)?.toInt() ?? 13;
    final rate = (d['tax_credit_rate_percent'] as num?)?.toDouble() ?? 0.7;
    final limit = (d['tax_credit_loan_limit'] as num?)?.toInt() ?? 0;
    final cap = (d['tax_credit_annual_cap'] as num?)?.toInt() ?? 0;
    final lastYear = moveIn + years - 1;
    final start = fromYear > moveIn ? fromYear : moveIn;

    return [
      for (var y = start; y <= lastYear; y++)
        (
          year: y,
          credit: annualTaxCredit(
            yearEndBalance: balanceFromDetails(d, year: y, month: 12),
            ratePercent: rate,
            loanLimit: limit,
            annualCap: cap,
          ),
        ),
    ];
  }

  /// 今月の返済額を利息と元本に分ける（元利均等・月利 = 年利 / 12）。
  static LoanPaymentSplit splitPayment({
    required int loanBalance,
    required double interestRatePercent,
    required int monthlyPayment,
  }) {
    if (loanBalance <= 0 || monthlyPayment <= 0) {
      return const LoanPaymentSplit(interest: 0, principal: 0);
    }
    final monthlyRate = interestRatePercent / 100.0 / 12.0;
    final interest = monthlyRate > 0 ? (loanBalance * monthlyRate).round() : 0;
    var principal = monthlyPayment - interest;
    if (principal < 0) principal = 0;
    if (principal > loanBalance) principal = loanBalance;
    return LoanPaymentSplit(interest: interest, principal: principal);
  }
}

/// 住宅ローン控除の設定（real_estate_details の tax_credit_* 列）
class TaxCreditSettings {
  const TaxCreditSettings({
    required this.moveInYear,
    required this.ratePercent,
    required this.years,
    required this.loanLimit,
    required this.annualCap,
  });

  factory TaxCreditSettings.fromDetails(Map<String, dynamic> d) =>
      TaxCreditSettings(
        moveInYear: (d['tax_credit_move_in_year'] as num?)?.toInt(),
        ratePercent: (d['tax_credit_rate_percent'] as num?)?.toDouble() ?? 0.7,
        years: (d['tax_credit_years'] as num?)?.toInt() ?? 13,
        loanLimit: (d['tax_credit_loan_limit'] as num?)?.toInt() ?? 0,
        annualCap: (d['tax_credit_annual_cap'] as num?)?.toInt() ?? 0,
      );

  /// 入居年。null なら控除を計算しない。
  final int? moveInYear;
  final double ratePercent;
  final int years;

  /// 0 なら上限なし
  final int loanLimit;

  /// 0 なら上限なし
  final int annualCap;

  Map<String, dynamic> toColumns() => {
        'tax_credit_move_in_year': moveInYear,
        'tax_credit_rate_percent': ratePercent,
        'tax_credit_years': years,
        'tax_credit_loan_limit': loanLimit,
        'tax_credit_annual_cap': annualCap,
      };
}

class LoanPaymentSplit {
  const LoanPaymentSplit({required this.interest, required this.principal});

  /// 利息（費用）
  final int interest;

  /// 元本（正味の持ち分に移る分）
  final int principal;
}
