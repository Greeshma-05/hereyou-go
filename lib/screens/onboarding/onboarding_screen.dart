import '../../core/constants/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/accessibility_button.dart';
import '../../widgets/route_artwork.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12),
            Row(
              children: [
                AppLogo(),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppBrand.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const AccessibilityButton(),
              ],
            ),
            SizedBox(height: 34),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                color: AppTheme.colors(context).surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RouteArtwork(height: 230),
                    Padding(
                      padding: EdgeInsets.fromLTRB(22, 0, 22, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(text: 'A BETTER NEXT STOP'),
                          SizedBox(height: 15),
                          Text(
                            'Less worry.\nMore of the journey.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(
                                Icons.restaurant_outlined,
                                color: AppTheme.colors(context).accent,
                              ),
                              SizedBox(width: 20),
                              Icon(
                                Icons.local_pharmacy_outlined,
                                color: AppTheme.colors(context).accent,
                              ),
                              SizedBox(width: 20),
                              Icon(
                                Icons.spa_outlined,
                                color: AppTheme.colors(context).accent,
                              ),
                              SizedBox(width: 20),
                              Icon(
                                Icons.luggage_outlined,
                                color: AppTheme.colors(context).accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Your journey.\n'),
                  TextSpan(
                    text: 'Your essentials.',
                    style: TextStyle(
                      color: AppTheme.colors(context).accent,
                      fontStyle: AppTheme.readingFont(context)
                          ? FontStyle.normal
                          : FontStyle.italic,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 14),
            Text(
              'A warm meal. Everyday care. The things you forgot. Find what you need at your next bus or train stop.',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppTheme.colors(context).muted,
              ),
            ),
            SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.read<SessionProvider>().introduce(),
                label: Text('Get Started'),
                icon: Icon(Icons.north_east),
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Made for the miles ahead.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.colors(context).muted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
