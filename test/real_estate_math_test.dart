import 'package:asset_note/utils/real_estate_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shareRatio', () {
    test('1/2 は 0.5', () {
      expect(RealEstateMath.shareRatio(1, 2), 0.5);
    });
    test('不正な値は単独所有とみなす', () {
      expect(RealEstateMath.shareRatio(0, 2), 1.0);
      expect(RealEstateMath.shareRatio(1, 0), 1.0);
      expect(RealEstateMath.shareRatio(3, 2), 1.0);
    });
  });

  test('自分の評価額と正味の持ち分', () {
    final own = RealEstateMath.ownMarketValue(60000000, 0.5);
    expect(own, 30000000);
    expect(RealEstateMath.netEquity(own, 22000000), 8000000);
  });

  test('自分の取得原価 = 物件価格 × 持分 + 初期費用', () {
    expect(
      RealEstateMath.ownCostBasis(
          purchasePrice: 50000000, share: 0.5, capitalizedInitialCosts: 1500000),
      26500000,
    );
  });

  group('elapsedYears', () {
    final acq = DateTime(2020, 4, 1);
    test('5か月は0年', () {
      expect(RealEstateMath.elapsedYears(acq, DateTime(2020, 9, 1)), 0);
    });
    test('6か月は1年に切り上げ', () {
      expect(RealEstateMath.elapsedYears(acq, DateTime(2020, 10, 1)), 1);
    });
    test('6年7か月は7年', () {
      expect(RealEstateMath.elapsedYears(acq, DateTime(2026, 11, 21)), 7);
    });
    test('取得前は0年', () {
      expect(RealEstateMath.elapsedYears(acq, DateTime(2019, 1, 1)), 0);
    });
  });

  group('ownBookValue', () {
    test('内訳が無ければ null', () {
      expect(
        RealEstateMath.ownBookValue(
          purchasePrice: 50000000,
          landPrice: 0,
          buildingPrice: 0,
          share: 1,
          capitalizedInitialCosts: 0,
          acquisitionDate: DateTime(2020, 1, 1),
          asOf: DateTime(2030, 1, 1),
        ),
        isNull,
      );
    });

    test('建物だけ減価償却される（単独所有・10年）', () {
      // 土地 2,000万 + 建物 3,000万。建物の減価 = 3,000万 × 0.9 × 0.015 × 10 = 405万
      final v = RealEstateMath.ownBookValue(
        purchasePrice: 50000000,
        landPrice: 20000000,
        buildingPrice: 30000000,
        share: 1,
        capitalizedInitialCosts: 0,
        acquisitionDate: DateTime(2020, 1, 1),
        asOf: DateTime(2030, 1, 1),
      );
      expect(v, 50000000 - 4050000);
    });

    test('持分と初期費用は内訳の比率で振り分ける', () {
      // 自分の分: 物件 2,500万 + 初期費用 100万 = 2,600万（土地40% / 建物60%）
      // 建物 1,560万 の減価 = 1,560万 × 0.9 × 0.015 × 10 = 210.6万
      final v = RealEstateMath.ownBookValue(
        purchasePrice: 50000000,
        landPrice: 20000000,
        buildingPrice: 30000000,
        share: 0.5,
        capitalizedInitialCosts: 1000000,
        acquisitionDate: DateTime(2020, 1, 1),
        asOf: DateTime(2030, 1, 1),
      );
      expect(v, 26000000 - 2106000);
    });

    test('建物は取得価額の5%より下がらない', () {
      final v = RealEstateMath.ownBookValue(
        purchasePrice: 30000000,
        landPrice: 0,
        buildingPrice: 30000000,
        share: 1,
        capitalizedInitialCosts: 0,
        acquisitionDate: DateTime(1950, 1, 1),
        asOf: DateTime(2026, 1, 1),
      );
      expect(v, 1500000);
    });
  });

  group('projectedBalance', () {
    test('起点の月以前は起点の残高のまま', () {
      expect(
        RealEstateMath.projectedBalance(
          anchorBalance: 30000000,
          anchorMonth: DateTime(2026, 11),
          asOf: DateTime(2026, 11),
          interestRatePercent: 0.6,
          monthlyPayment: 90000,
        ),
        30000000,
      );
    });

    test('1か月ごとに元本を引く', () {
      // 1か月目: 利息 15,000 / 元本 75,000 → 29,925,000
      // 2か月目: 利息 14,963 / 元本 75,037 → 29,849,963
      expect(
        RealEstateMath.projectedBalance(
          anchorBalance: 30000000,
          anchorMonth: DateTime(2026, 11),
          asOf: DateTime(2027, 1),
          interestRatePercent: 0.6,
          monthlyPayment: 90000,
        ),
        29849963,
      );
    });

    test('完済後は0で止まる', () {
      expect(
        RealEstateMath.projectedBalance(
          anchorBalance: 100000,
          anchorMonth: DateTime(2026, 1),
          asOf: DateTime(2027, 1),
          interestRatePercent: 0,
          monthlyPayment: 90000,
        ),
        0,
      );
    });
  });

  group('balanceFromDetails', () {
    test('起点の月が無ければ保存された残高を返す', () {
      expect(
        RealEstateMath.balanceFromDetails(
          {'current_loan_balance': 30000000, 'monthly_payment': 90000},
          year: 2030,
          month: 1,
        ),
        30000000,
      );
    });

    test('何度計算しても同じ月なら同じ残高（二重に引かない）', () {
      final d = {
        'current_loan_balance': 30000000,
        'loan_balance_as_of': '2026-11-01',
        'interest_rate_percent': 0.6,
        'monthly_payment': 90000,
      };
      final a = RealEstateMath.balanceFromDetails(d, year: 2026, month: 12);
      final b = RealEstateMath.balanceFromDetails(d, year: 2026, month: 12);
      expect(a, 29925000);
      expect(b, a);
    });
  });

  group('annualTaxCredit', () {
    test('年末残高 × 0.7%、100円未満切り捨て', () {
      expect(
        RealEstateMath.annualTaxCredit(
            yearEndBalance: 29925050, ratePercent: 0.7),
        209400,
      );
    });
    test('借入限度額で頭打ち', () {
      expect(
        RealEstateMath.annualTaxCredit(
            yearEndBalance: 40000000, ratePercent: 0.7, loanLimit: 30000000),
        210000,
      );
    });
    test('税額の上限で頭打ち', () {
      expect(
        RealEstateMath.annualTaxCredit(
            yearEndBalance: 40000000, ratePercent: 0.7, annualCap: 150000),
        150000,
      );
    });
  });

  group('taxCreditSchedule', () {
    final d = {
      'current_loan_balance': 30000000,
      'loan_balance_as_of': '2026-12-01',
      'interest_rate_percent': 0.0,
      'monthly_payment': 100000,
      'tax_credit_move_in_year': 2026,
      'tax_credit_years': 3,
      'tax_credit_rate_percent': 0.7,
    };
    test('入居年が無ければ空', () {
      expect(RealEstateMath.taxCreditSchedule({}, fromYear: 2026), isEmpty);
    });
    test('控除期間の各年を年末残高で計算する', () {
      final s = RealEstateMath.taxCreditSchedule(d, fromYear: 2026);
      expect(s.map((e) => e.year), [2026, 2027, 2028]);
      // 2026末 3,000万 / 2027末 2,880万 / 2028末 2,760万
      expect(s.map((e) => e.credit), [210000, 201600, 193200]);
    });
    test('途中の年からは残りの年だけ', () {
      final s = RealEstateMath.taxCreditSchedule(d, fromYear: 2028);
      expect(s.map((e) => e.year), [2028]);
    });
  });

  group('splitPayment', () {
    test('利息と元本に分ける', () {
      // 3,000万 × 0.6% / 12 = 15,000
      final s = RealEstateMath.splitPayment(
          loanBalance: 30000000, interestRatePercent: 0.6, monthlyPayment: 90000);
      expect(s.interest, 15000);
      expect(s.principal, 75000);
    });
    test('利息が返済額を超えても元本はマイナスにならない', () {
      final s = RealEstateMath.splitPayment(
          loanBalance: 30000000, interestRatePercent: 6, monthlyPayment: 100000);
      expect(s.principal, 0);
    });
    test('元本は残高を超えない', () {
      final s = RealEstateMath.splitPayment(
          loanBalance: 50000, interestRatePercent: 0, monthlyPayment: 90000);
      expect(s.principal, 50000);
    });
  });
}
