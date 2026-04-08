import 'package:flutter/material.dart';

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
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ],
    ],
  );
}
