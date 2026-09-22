import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_language.dart';

/// Modern Native Quick-Commerce Quantity Selector (- QTY +)
class QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double height;
  final double width;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.height = 32.0,
    this.width = 84.0,
  });

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return SizedBox(
        height: height,
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onIncrement();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF16A34A),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('ADD'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.add,
                    size: 15,
                    color: Color(0xFF15803D),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF0F4A2F),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F4A2F).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              onTap: () {
                HapticFeedback.selectionClick();
                onDecrement();
              },
              child: Container(
                width: 26,
                height: height,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.remove,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              onTap: () {
                HapticFeedback.selectionClick();
                onIncrement();
              },
              child: Container(
                width: 26,
                height: height,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
