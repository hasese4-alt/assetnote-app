import 'package:flutter/material.dart';

// ── アイコン定義 ────────────────────────────────────────────────

class CategoryIconDef {
  const CategoryIconDef(this.key, this.label, this.data);
  final String key;
  final String label;
  final IconData data;
}

const kCategoryIcons = [
  CategoryIconDef('account_balance', '銀行', Icons.account_balance),
  CategoryIconDef('credit_card', 'カード', Icons.credit_card),
  CategoryIconDef('savings', '貯金', Icons.savings),
  CategoryIconDef('trending_up', '株・投資', Icons.trending_up),
  CategoryIconDef('currency_bitcoin', '暗号資産', Icons.currency_bitcoin),
  CategoryIconDef('home', '不動産', Icons.home),
  CategoryIconDef('directions_car', '車', Icons.directions_car),
  CategoryIconDef('devices', '機器', Icons.devices),
  CategoryIconDef('account_balance_wallet', 'ウォレット', Icons.account_balance_wallet),
  CategoryIconDef('payments', '現金', Icons.payments),
  CategoryIconDef('monetization_on', '資産', Icons.monetization_on),
  CategoryIconDef('diamond', '貴重品', Icons.diamond),
  CategoryIconDef('local_atm', 'ATM', Icons.local_atm),
  CategoryIconDef('bar_chart', 'チャート', Icons.bar_chart),
  CategoryIconDef('work', '仕事', Icons.work),
  CategoryIconDef('star', 'その他', Icons.star),
];

IconData? categoryIconDataForKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final def in kCategoryIcons) {
    if (def.key == key) return def.data;
  }
  return null;
}

// ── Favicon ────────────────────────────────────────────────────

/// 分類名とキーワードが部分一致したときの Google favicon URL を返す。
String? faviconUrlForCategoryLabel(String label) {
  if (label.isEmpty || label == '_') return null;

  final text = label.toLowerCase();

  const map = {
    '楽天': 'rakuten.co.jp',
    'rakuten': 'rakuten.co.jp',
    'sbi': 'sbisec.co.jp',
    'pokemon': 'pokemon.com',
    'ポケモン': 'pokemon.com',
    '三菱ufj': 'mufg.jp',
    'ufj': 'mufg.jp',
    '三井住友': 'smbc.co.jp',
    'みずほ': 'mizuhobank.co.jp',
    'りそな': 'resonabank.co.jp',
    'ゆうちょ': 'jp-bank.japanpost.jp',
    'paypay銀行': 'paypay-bank.co.jp',
    'マネックス': 'monex.co.jp',
    '松井証券': 'matsui.co.jp',
    '野村': 'nomura.co.jp',
    '大和証券': 'daiwa.jp',
    'paypay': 'paypay.ne.jp',
    'メルカリ': 'mercari.com',
    'line pay': 'line.me',
    'au pay': 'au.com',
    'd払い': 'dpoint.jp',
    'apple': 'apple.com',
    'google': 'google.com',
    'amazon': 'amazon.co.jp',
    'microsoft': 'microsoft.com',
    'visa': 'visa.com',
    'mastercard': 'mastercard.com',
    'jcb': 'jcb.co.jp',
    'amex': 'americanexpress.com',
    'エポス': 'eposcard.co.jp',
    'epos': 'eposcard.co.jp',
    'イオン': 'aeon.co.jp',
    'ビューカード': 'jreast.co.jp',
    'view': 'jreast.co.jp',
    'coincheck': 'coincheck.com',
    'コインチェック': 'coincheck.com',
    'bitflyer': 'bitflyer.com',
    '三井住友銀行': 'smbc.co.jp',
    'smbc': 'smbc.co.jp',
    'au': 'au.com',
    'スニダン': 'snkrdunk.com',
    'snkrdunk': 'snkrdunk.com',
    'スニーカーダンク': 'snkrdunk.com',
  };

  for (final entry in map.entries) {
    if (text.contains(entry.key.toLowerCase())) {
      return 'https://www.google.com/s2/favicons?sz=128&domain=${entry.value}';
    }
  }
  return null;
}

/// Puts the favicon immediately after the label (tight to the text, not the row end).
Widget categoryTitleWithOptionalFavicon({
  required String label,
  required TextStyle style,
  double iconSize = 18,
}) {
  final url = faviconUrlForCategoryLabel(label);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Flexible(
        child: Text(
          label,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (url != null) ...[
        const SizedBox(width: 6),
        Image.network(
          url,
          width: iconSize,
          height: iconSize,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    ],
  );
}
