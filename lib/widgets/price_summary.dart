import 'package:flutter/material.dart';
import '../core/utils/formatters.dart';

class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    required this.delivery,
    required this.platform,
  });
  final int subtotal;
  final int delivery;
  final int platform;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _line(context, 'Item subtotal', subtotal),
          _line(context, 'Delivery fee · sample', delivery),
          _line(context, 'Platform fee · sample', platform),
          const Divider(height: 24),
          _line(context, 'Total', subtotal + delivery + platform, bold: true),
        ],
      ),
    ),
  );
  Widget _line(
    BuildContext context,
    String label,
    int price, {
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: bold ? Theme.of(context).textTheme.titleMedium : null,
          ),
        ),
        Text(
          money(price),
          style: bold ? Theme.of(context).textTheme.titleMedium : null,
        ),
      ],
    ),
  );
}
