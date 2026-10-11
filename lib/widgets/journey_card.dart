import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/navigation.dart';
import '../models/journey_model.dart';
import '../screens/journey/journey_screen.dart';
import 'common.dart';

class JourneyCard extends StatelessWidget {
  const JourneyCard({super.key, required this.journey, this.editable = true});
  final Journey journey;
  final bool editable;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.colors(context).tint,
          AppTheme.colors(context).surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: AppTheme.colors(context).border),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  journey.mode == JourneyMode.bus
                      ? Icons.directions_bus_rounded
                      : Icons.train_rounded,
                  color: AppTheme.colors(context).ink,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'YOUR JOURNEY',
                    style: TextStyle(
                      color: AppTheme.colors(context).ink,
                      fontSize: 11,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const StatusBadge(text: 'YOUR NEXT STOP'),
          ],
        ),
        SizedBox(height: 18),
        Text(
          '${journey.boarding} → ${journey.destination}',
          style: TextStyle(
            color: AppTheme.colors(context).ink,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${dateLabel(journey.departure)} · ${timeLabel(journey.departure)}',
          style: TextStyle(color: AppTheme.colors(context).muted),
        ),
        Divider(color: AppTheme.colors(context).border, height: 30),
        Row(
          children: [
            Icon(
              Icons.trip_origin,
              color: AppTheme.colors(context).ink,
              size: 18,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                journey.pickup.name,
                style: TextStyle(color: AppTheme.colors(context).ink),
              ),
            ),
            if (editable)
              IconButton(
                tooltip: 'Edit journey',
                onPressed: () => openPage(context, JourneyScreen()),
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppTheme.colors(context).ink,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
