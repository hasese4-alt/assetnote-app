import 'package:flutter/material.dart';

class MonthlyConfirmToggle extends StatelessWidget {
  const MonthlyConfirmToggle({
    super.key,
    required this.isConfirmed,
    required this.onTap,
  });

  final bool isConfirmed;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.33,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isConfirmed
              ? Colors.green.withOpacity(0.10)
              : Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isConfirmed
                ? Colors.green.withOpacity(0.5)
                : Colors.grey.withOpacity(0.5),
          ),
        ),
        child: Center(
          child: Text(
            isConfirmed ? 'Confirmed' : 'Draft',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isConfirmed ? Colors.green.shade600 : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
