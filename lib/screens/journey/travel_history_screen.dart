import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../providers/journey_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/journey_card.dart';

class TravelHistoryScreen extends StatelessWidget {
  const TravelHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final journeys = context.watch<JourneyProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Travel history')),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Notice(
                journeys.cloudBacked
                    ? 'Your saved journeys, synced to your account.'
                    : 'Guest journeys are kept for this session. Sign in to save them across devices.',
              ),
              if (journeys.loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (journeys.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Notice(journeys.error!, warning: true),
                ),
              if (!journeys.loading && journeys.history.isEmpty)
                const EmptyState(
                  icon: Icons.route_outlined,
                  title: 'The miles are ahead of you',
                  message:
                      'Save a bus or train journey and find it here next time.',
                ),
              for (final past in [false, true]) ...[
                if (journeys.history.any(
                  (saved) =>
                      saved.journey.departure.isBefore(DateTime.now()) == past,
                ))
                  SectionHeading(past ? 'Past journeys' : 'Upcoming journeys'),
                for (final saved in journeys.history.where(
                  (saved) =>
                      saved.journey.departure.isBefore(DateTime.now()) == past,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        JourneyCard(journey: saved.journey, editable: false),
                        const SizedBox(height: 6),
                        Text(
                          'Saved ${dateLabel(saved.savedAt)} · ${timeLabel(saved.savedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
