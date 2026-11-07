import 'package:asset_note/pages/real_estate_add_page.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/app_dialogs.dart';
import 'package:asset_note/widgets/asset_form_fields.dart';
import 'package:asset_note/widgets/icon_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAssetPage extends StatefulWidget {
  const AddAssetPage({super.key, required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends State<AddAssetPage> {
  final name = TextEditingController();
  final value = TextEditingController();
  final acquisitionPrice = TextEditingController();

  late final AssetsRepository _repository;

  List<Map<String, dynamic>> parentCategories = [];
  Map<String, List<Map<String, dynamic>>> childCategories = {};

  String? selectedC1Id;
  String? selectedC2Id;

  String? _iconLabel;
  Color? _iconTextColor;
  Color? _iconBgColor;
  bool _hideFavicon = false;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return widget.year == now.year && widget.month == now.month;
  }

  bool get _isRealEstateCategory {
    if (selectedC1Id == null) return false;
    for (final c in parentCategories) {
      if (c['id'] == selectedC1Id && c['icon'] == 'home') return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    loadCategories();
  }

  @override
  void dispose() {
    name.dispose();
    value.dispose();
    acquisitionPrice.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    final h = await _repository.fetchCategoryHierarchy();
    if (!mounted) return;
    setState(() {
      parentCategories = h.parentCategories;
      childCategories = h.childCategories;
    });
  }

  String? _resolveCategory1Name() {
    if (selectedC1Id == null) return null;
    for (final c in parentCategories) {
      if (c['id'] == selectedC1Id) return c['name'] as String?;
    }
    return null;
  }

  String? _resolveCategory2Name() {
    if (selectedC2Id == null) return null;
    for (final list in childCategories.values) {
      for (final c in list) {
        if (c['id'] == selectedC2Id) return c['name'] as String?;
      }
    }
    return null;
  }

  Future<void> addAsset() async {
    if (name.text.trim().isEmpty) {
      showMissingFieldDialog(context, '名称を入力してください。');
      return;
    }

    if (value.text.trim().isEmpty) {
      showMissingFieldDialog(context, '金額を入力してください。');
      return;
    }

    if (selectedC1Id == null) {
      showMissingFieldDialog(context, 'カテゴリを選択してください。');
      return;
    }

    final acqPrice = int.tryParse(acquisitionPrice.text.trim());

    final iconTextHex = _iconTextColor != null ? colorToHex(_iconTextColor!) : null;
    final iconBgHex = _iconBgColor != null ? colorToHex(_iconBgColor!) : null;

    if (_isCurrentMonth) {
      await _repository.insertAsset(
        name: name.text,
        value: int.tryParse(value.text) ?? 0,
        category1Id: selectedC1Id,
        category2Id: selectedC2Id,
        acquisitionPrice: acqPrice,
        iconLabel: _iconLabel,
        iconTextColor: iconTextHex,
        iconBgColor: iconBgHex,
        hideFavicon: _hideFavicon,
      );
    } else {
      await _repository.insertAssetWithHistory(
        name: name.text,
        value: int.tryParse(value.text) ?? 0,
        category1Id: selectedC1Id,
        category2Id: selectedC2Id,
        category1Name: _resolveCategory1Name(),
        category2Name: _resolveCategory2Name(),
        year: widget.year,
        month: widget.month,
        acquisitionPrice: acqPrice,
        iconLabel: _iconLabel,
        iconTextColor: iconTextHex,
        iconBgColor: iconBgHex,
        hideFavicon: _hideFavicon,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _navigateToRealEstate(
      String c1Id, String? c2Id, VoidCallback onSaved) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RealEstateAddPage(
          year: widget.year,
          month: widget.month,
          preselectedC1Id: c1Id,
          preselectedC2Id: c2Id,
        ),
      ),
    );
    if (saved == true && mounted) onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          '資産を追加',
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          AssetFormFields(
            nameController: name,
            valueController: value,
            acquisitionPriceController: acquisitionPrice,
            parentCategories: parentCategories,
            childCategories: childCategories,
            selectedC1Id: selectedC1Id,
            selectedC2Id: selectedC2Id,
            onParentChanged: (v) {
              setState(() {
                selectedC1Id = v;
                selectedC2Id = null;
              });
            },
            onChildChanged: (v) {
              setState(() => selectedC2Id = v);
            },
            iconLabel: _iconLabel,
            iconTextColor: _iconTextColor,
            iconBgColor: _iconBgColor,
            onIconChanged: (label, textColor, bgColor) {
              setState(() {
                _iconLabel = label;
                _iconTextColor = textColor;
                _iconBgColor = bgColor;
              });
            },
            hideFavicon: _hideFavicon,
            onHideFaviconChanged: (v) => setState(() => _hideFavicon = v),
          ),
          const SizedBox(height: 32),
          if (_isRealEstateCategory) ...[
            FilledButton.tonal(
              onPressed: () => _navigateToRealEstate(
                  selectedC1Id!, selectedC2Id, () => Navigator.pop(context)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: const StadiumBorder(),
              ),
              child: const Text('不動産の詳細を入力する →',
                  style: TextStyle(fontSize: 16)),
            ),
          ] else ...[
            FilledButton(
              onPressed: addAsset,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: const StadiumBorder(),
              ),
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}
