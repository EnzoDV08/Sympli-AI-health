import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class QuickAskSection extends StatelessWidget {
  final void Function(String label)? onSelect;
  const QuickAskSection({super.key, this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(
              CupertinoIcons.question_circle_fill,
              color: Color(0xFF5C8CFF),
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              "Quick Ask 💬",
              style: TextStyle(
                color: Color(0xFF3B5FFF),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _QuickAskChip(
                label: "Medication",
                asset: 'assets/icons/ic_medication.png',
                bgColor: Color(0xFFFFC043),
                onTap: onSelect,
              ),
              _QuickAskChip(
                label: "Symptom",
                asset: 'assets/icons/ic_symptom.png',
                bgColor: Color(0xFFFF6F61),
                onTap: onSelect,
              ),
              _QuickAskChip(
                label: "AI Help",
                asset: 'assets/icons/ic_aihelp.png',
                bgColor: Color(0xFF52E3C2),
                onTap: onSelect,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAskChip extends StatelessWidget {
  final String label;
  final String asset;
  final Color bgColor;
  final void Function(String label)? onTap;

  const _QuickAskChip({
    required this.label,
    required this.asset,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap?.call(label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF3B5FFF),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
