import '../../core/constants/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../data/catalog.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/catalog_status.dart';
import '../../widgets/nearby_search_controls.dart';
import '../../models/category.dart';
import '../../models/journey_model.dart';
import '../../models/nearby_area.dart';
import '../../providers/journey_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/accessibility_button.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/common.dart';
import '../../widgets/journey_card.dart';
import '../../widgets/product_card.dart';
import '../../widgets/route_artwork.dart';
import '../../widgets/vendor_card.dart';
import '../explore/explore_screen.dart';
import '../journey/journey_screen.dart';
import '../orders/order_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onProfile,
    required this.onExplore,
  });
  final VoidCallback onProfile;
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final customer = session.customer!;
    final journey = context.watch<JourneyProvider>().journey;
    final orders = context.watch<OrderProvider>().orders;
    final area = NearbyArea(
      mode: context.watch<JourneyProvider>().searchMode,
      devicePosition: context.watch<LocationProvider>().position,
      pickup: journey?.pickup,
    );
    final catalog = CatalogProvider.of(context);
    final nearbyShops = Catalog.searchVendorResults(
      '',
      null,
      area: area,
      vendors: catalog.vendors,
      products: catalog.products,
    );
    final nearbyProducts = Catalog.searchProducts(
      '',
      null,
      area: area,
      vendors: catalog.vendors,
      products: catalog.products,
    );
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Open profile',
                    onPressed: onProfile,
                    padding: EdgeInsets.zero,
                    icon: CircleAvatar(
                      radius: 23,
                      backgroundColor: AppTheme.colors(context).tint,
                      child: Text(
                        customer.name.isEmpty
                            ? 'T'
                            : customer.name.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.colors(context).accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${customer.name.split(' ').first}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Let’s make the miles easier.',
                          style: TextStyle(
                            color: AppTheme.colors(context).muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AccessibilityButton(),
                  const CartButton(),
                ],
              ),
              if (session.error != null) Notice(session.error!, warning: true),
              SizedBox(height: 28),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Ready for your\n'),
                    TextSpan(
                      text: 'next stop?',
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
              SizedBox(height: 22),
              TextField(
                readOnly: true,
                onTap: () =>
                    openPage(context, ExploreScreen(initialMap: false)),
                decoration: InputDecoration(
                  hintText: 'Search medicine, food, essentials…',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: Icon(Icons.tune_rounded, size: 19),
                ),
              ),
              const SizedBox(height: 16),
              const NearbySearchControls(),
              CatalogStatus(area: area),
              SectionHeading(
                'Delivery place',
                action: journey == null ? null : 'Change',
                onAction: () =>
                    openPage(context, const JourneyScreen(focusDelivery: true)),
              ),
              if (journey != null)
                JourneyCard(journey: journey)
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openPage(
                      context,
                      const JourneyScreen(focusDelivery: true),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RouteArtwork(height: 160),
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Where should we meet you?',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Type your address and add a map pin',
                                      style: TextStyle(
                                        color: AppTheme.colors(context).muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: AppTheme.colors(
                                  context,
                                ).accent,
                                child: Icon(
                                  Icons.north_east,
                                  color: AppTheme.colors(context).onAccent,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SectionHeading('What do you need?'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in Category.values)
                      Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => openPage(
                            context,
                            ExploreScreen(
                              initialCategory: category,
                              initialMap: false,
                            ),
                          ),
                          child: SizedBox(
                            width: 65,
                            child: Column(
                              children: [
                                CategoryArtwork(category, size: 60),
                                SizedBox(height: 9),
                                Text(
                                  category.shortLabel,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SectionHeading('Your journey, your way'),
              Row(
                children: [
                  Expanded(
                    child: _JourneyChoice(
                      mode: JourneyMode.bus,
                      title: 'Bus journey',
                      subtitle: 'Along your route',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _JourneyChoice(
                      mode: JourneyMode.train,
                      title: 'Train journey',
                      subtitle: 'At your next station',
                    ),
                  ),
                ],
              ),
              SectionHeading(
                'Finds around you',
                action: 'View map',
                onAction: onExplore,
              ),
              Text(
                '${area.rangeLabel} from ${area.source}',
                style: TextStyle(
                  color: AppTheme.colors(context).muted,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 12),
              if (!catalog.loading &&
                  catalog.error == null &&
                  nearbyShops.isEmpty)
                const Notice(
                  'No shops in this range. Open Explore to refresh your location or change the journey type.',
                ),
              for (final result in nearbyShops.take(3))
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: VendorCard(vendor: result.vendor),
                ),
              SectionHeading(
                'Packed for the journey',
                action: 'See all',
                onAction: () =>
                    openPage(context, ExploreScreen(initialMap: false)),
              ),
              for (final product in nearbyProducts.take(3))
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ProductCard(product: product),
                ),
              if (orders.isNotEmpty) ...[
                SectionHeading('Your latest order'),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.receipt_long_outlined,
                      color: AppTheme.colors(context).accent,
                    ),
                    title: Text(orders.first.status.label),
                    subtitle: Text(orders.first.reference),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => openPage(
                      context,
                      OrderDetailScreen(reference: orders.first.reference),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 32),
              Row(
                children: [
                  AppLogo(size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppBrand.name,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'MADE FOR THE MILES AHEAD',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: AppTheme.colors(context).muted,
                ),
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyChoice extends StatelessWidget {
  const _JourneyChoice({
    required this.mode,
    required this.title,
    required this.subtitle,
  });
  final JourneyMode mode;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => openPage(context, JourneyScreen(mode: mode)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mode == JourneyMode.bus
                      ? Icons.directions_bus_outlined
                      : Icons.train_outlined,
                  color: AppTheme.colors(context).accent,
                  size: 28,
                ),
                Spacer(),
                Icon(
                  Icons.north_east,
                  color: AppTheme.colors(context).muted,
                  size: 16,
                ),
              ],
            ),
            SizedBox(height: 22),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
