import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            centerTitle: false,
            title: Text(
              'プライバシーポリシー',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    context,
                    title: '収集する情報',
                    body:
                        '本アプリは、ユーザーが入力した資産名・金額・カテゴリ・取得価格などの資産情報を収集します。'
                        'その他の個人情報（氏名・メールアドレス等）は収集しません。',
                  ),
                  _section(
                    context,
                    title: 'データの保存先',
                    body:
                        '入力されたデータは Supabase（米国）のサーバーに保存されます。'
                        '本アプリはログイン不要の匿名認証を使用しており、データはデバイスごとに識別されます。',
                  ),
                  _section(
                    context,
                    title: '第三者への提供',
                    body: '収集したデータを広告配信・分析目的で第三者に提供することはありません。',
                  ),
                  _section(
                    context,
                    title: 'データの消失リスク',
                    body:
                        '本アプリは匿名認証を採用しています。アプリの削除や機種変更を行った場合、'
                        'サーバー上のデータにアクセスできなくなります。'
                        '大切なデータは設定画面のバックアップ機能で定期的に保存してください。',
                  ),
                  _section(
                    context,
                    title: 'ポリシーの変更',
                    body:
                        '本ポリシーはアプリのアップデートにより変更される場合があります。'
                        '重要な変更がある場合はアプリ内でお知らせします。',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '最終更新日：2025年8月',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFAEAEB2)
                  : const Color(0xFF3C3C43),
            ),
          ),
        ],
      ),
    );
  }
}
