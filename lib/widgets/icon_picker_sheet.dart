import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kColors = [
  Color(0xFFFFFFFF),
  Color(0xFF000000),
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF007AFF),
  Color(0xFFAF52DE),
  Color(0xFFFF2D55),
  Color(0xFF8E8E93),
];

Future<({String label, Color textColor, Color bgColor})?> showIconPickerSheet(
  BuildContext context, {
  String? currentLabel,
  Color? currentTextColor,
  Color? currentBgColor,
}) {
  return showModalBottomSheet<({String label, Color textColor, Color bgColor})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IconPickerSheet(
      initialLabel: currentLabel ?? '',
      initialTextColor: currentTextColor ?? Colors.white,
      initialBgColor: currentBgColor ?? const Color(0xFF007AFF),
    ),
  );
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({
    required this.initialLabel,
    required this.initialTextColor,
    required this.initialBgColor,
  });

  final String initialLabel;
  final Color initialTextColor;
  final Color initialBgColor;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  late final TextEditingController _labelCtrl;
  late Color _textColor;
  late Color _bgColor;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.initialLabel);
    _textColor = widget.initialTextColor;
    _bgColor = widget.initialBgColor;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final labelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: _IconPreview(
                label: _labelCtrl.text,
                textColor: _textColor,
                bgColor: _bgColor,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: '文字', color: labelColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: TextField(
                controller: _labelCtrl,
                maxLength: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                  hintText: 'A',
                  hintStyle: TextStyle(fontSize: 24, color: Color(0xFFAEAEB2)),
                ),
                inputFormatters: [],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(label: '文字色', color: labelColor),
            const SizedBox(height: 8),
            _ColorSwatchRow(
              selected: _textColor,
              onSelected: (c) => setState(() => _textColor = c),
            ),
            const SizedBox(height: 20),
            _SectionLabel(label: '背景色', color: labelColor),
            const SizedBox(height: 8),
            _ColorSwatchRow(
              selected: _bgColor,
              onSelected: (c) => setState(() => _bgColor = c),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, (
                  label: _labelCtrl.text.trim(),
                  textColor: _textColor,
                  bgColor: _bgColor,
                ));
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: const StadiumBorder(),
              ),
              child: const Text('完了', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
      );
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.selected, required this.onSelected});
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kColors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _kColors[i];
          final isSelected = c.toARGB32() == selected.toARGB32();
          return GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (c == const Color(0xFFFFFFFF)
                          ? const Color(0xFFD1D1D6)
                          : Colors.transparent),
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: c == const Color(0xFFFFFFFF) || c == const Color(0xFFFFCC00)
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class IconPreview extends StatelessWidget {
  const IconPreview({
    super.key,
    required this.label,
    required this.textColor,
    required this.bgColor,
    this.size = 30,
  });

  final String label;
  final Color textColor;
  final Color bgColor;
  final double size;

  @override
  Widget build(BuildContext context) => _IconPreview(
        label: label,
        textColor: textColor,
        bgColor: bgColor,
        size: size,
      );
}

class _IconPreview extends StatelessWidget {
  const _IconPreview({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.size,
  });

  final String label;
  final Color textColor;
  final Color bgColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final displayText = label.isNotEmpty ? label : '?';
    final fontSize = size * 0.4;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: bgColor == const Color(0xFFFFFFFF)
            ? Border.all(color: const Color(0xFFD1D1D6), width: 0.5)
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

String colorToHex(Color color) {
  final argb = color.toARGB32();
  final hex = argb.toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2).toUpperCase()}';
}

Color? hexToColor(String? hex) {
  if (hex == null) return null;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return null;
  }
}
