import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/category_favicon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteAssetPage extends StatefulWidget {
  const DeleteAssetPage({
    super.key,
    required this.activeYear,
    required this.activeMonth,
  });

  final int activeYear;
  final int activeMonth;

  @override
  State<DeleteAssetPage> createState() => _DeleteAssetPageState();
}

class _DeleteAssetPageState extends State<DeleteAssetPage> {
  late final AssetsRepository _repository;
  List<Map<String, dynamic>> _assets = [];
  bool _loading = true;
  final _fmt = NumberFormat('#,###', 'ja_JP');

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _fetch();
  }

  Future<void> _fetch() async {
    final assets = await _repository.fetchCurrentAssets();
    if (!mounted) return;
    assets.sort((a, b) => (b['value'] ?? 0).compareTo(a['value'] ?? 0));
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  void _showSellSheet(Map<String, dynamic> asset) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SellSheet(
        asset: asset,
        fmt: _fmt,
        onSell: (sellPrice, acquisitionPrice) => _repository.sellAsset(
          assetId: asset['id'] as int,
          assetName: asset['name'] as String? ?? '',
          sellPrice: sellPrice,
          acquisitionPrice: acquisitionPrice,
          memoDate: DateTime(widget.activeYear, widget.activeMonth, 15),
        ),
      ),
    ).then((sold) {
      if (sold == true && mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          '資産を処分',
          style: Theme.of(context)
              .textTheme
              .titleLarge!
              .copyWith(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? const Center(child: Text('資産がありません'))
              : ListView.separated(
                  itemCount: _assets.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                  itemBuilder: (context, i) {
                    final asset = _assets[i];
                    final name = asset['name'] as String? ?? '';
                    final value = asset['value'] as int? ?? 0;
                    final c1 = asset['categories1'] as Map<String, dynamic>?;
                    final c1Name = c1?['name'] as String? ?? '';
                    final iconData = categoryIconDataForKey(c1?['icon'] as String?);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primary.withValues(alpha: 0.1),
                        child: Icon(
                          iconData ?? Icons.monetization_on,
                          color: primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: c1Name.isNotEmpty ? Text(c1Name) : null,
                      trailing: Text(
                        '¥${_fmt.format(value)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _showSellSheet(asset),
                    );
                  },
                ),
    );
  }
}

class _SellSheet extends StatefulWidget {
  const _SellSheet({
    required this.asset,
    required this.fmt,
    required this.onSell,
  });

  final Map<String, dynamic> asset;
  final NumberFormat fmt;
  final Future<void> Function(int sellPrice, int acquisitionPrice) onSell;

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  final _sellController = TextEditingController();
  final _acquisitionController = TextEditingController();
  bool _submitting = false;

  int? get _sellPrice => int.tryParse(_sellController.text);
  int? get _acquisitionPrice => int.tryParse(_acquisitionController.text);
  int? get _profit {
    final sell = _sellPrice;
    final acq = _acquisitionPrice;
    if (sell == null || acq == null) return null;
    return sell - acq;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.asset['acquisition_price'] as int?;
    if (existing != null) {
      _acquisitionController.text = existing.toString();
    }
  }

  String _formatProfit(int profit) {
    final abs = widget.fmt.format(profit.abs());
    return profit >= 0 ? '+¥$abs' : '-¥$abs';
  }

  @override
  void dispose() {
    _sellController.dispose();
    _acquisitionController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final sell = _sellPrice;
    final acq = _acquisitionPrice;
    if (sell == null || acq == null) return;
    setState(() => _submitting = true);
    await widget.onSell(sell, acq);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final separatorColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    final secondaryLabel = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73);
    final name = widget.asset['name'] as String? ?? '';
    final profit = _profit;

    Color profitColor = Theme.of(context).colorScheme.onSurface;
    if (profit != null) {
      profitColor = profit >= 0
          ? const Color(0xFF34C759)
          : const Color(0xFFFF3B30);
    }

    final canSubmit = _sellPrice != null && _acquisitionPrice != null && !_submitting;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InputRow(
                    label: '売却価格',
                    controller: _sellController,
                    onChanged: (_) => setState(() {}),
                    labelColor: secondaryLabel,
                  ),
                  Divider(height: 1, indent: 16, color: separatorColor),
                  _InputRow(
                    label: '取得価格',
                    controller: _acquisitionController,
                    onChanged: (_) => setState(() {}),
                    labelColor: secondaryLabel,
                  ),
                  Divider(height: 1, indent: 16, color: separatorColor),
                  _InfoRow(
                    label: '収益',
                    value: profit != null ? _formatProfit(profit) : '—',
                    valueColor: profit != null ? profitColor : null,
                    labelColor: secondaryLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: canSubmit ? _confirm : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFFFF3B30),
                  disabledBackgroundColor:
                      const Color(0xFFFF3B30).withValues(alpha: 0.4),
                  shape: const StadiumBorder(),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '売却して削除',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 15)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.labelColor,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 15)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: labelColor),
                prefixText: '¥',
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
