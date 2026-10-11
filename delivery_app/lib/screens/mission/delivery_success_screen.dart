import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/demo_format.dart';
import '../../models/delivery_request.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/roo_tip.dart';

class DeliverySuccessScreen extends StatelessWidget {
  const DeliverySuccessScreen({
    required this.order,
    required this.firstDelivery,
    super.key,
  });
  final DeliveryRequest order;
  final bool firstDelivery;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mission complete')),
    body: SafeArea(
      child: AppPage(
        storageId: 'delivery-success',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Center(
              child: Icon(
                Icons.check_circle_rounded,
                size: 92,
                color: AppColors.lime,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'You moved\na journey forward.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '${order.id} · Delivered to ${order.traveler}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AppCard(
              child: Column(
                children: [
                  Text(
                    DemoFormat.money(order.rewardPaise),
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(color: AppColors.lime),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Demo reward recorded',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Earnings and History have been updated.\nNo real payment was made.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            RooTip(
              title: firstDelivery
                  ? 'Your first demo delivery!'
                  : 'Another journey, made better',
              message: 'A little care goes a long way. Your next mission will be waiting when you are ready.',
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Return to your journey',
              icon: Icons.arrow_forward_rounded,
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
            ),
          ],
        ),
      ),
    ),
  );
}
