import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/demo_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../data/catalog.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/catalog_status.dart';
import '../../models/category.dart';
import '../../models/nearby_area.dart';
import '../../providers/journey_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/common.dart';
import '../../widgets/location_panel.dart';
import '../../widgets/nearby_search_controls.dart';
import '../../widgets/product_card.dart';
import '../../widgets/vendor_card.dart';
import '../journey/journey_screen.dart';
import 'vendor_map.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.initialCategory,
    this.initialQuery = '',
    this.initialMap = true,
  });
  final Category? initialCategory;
  final String initialQuery;
  final bool initialMap;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final TextEditingController _search;
  Category? _category;
  late bool _map;
  final _mapAnchor = GlobalKey();
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _category = widget.initialCategory;
    _map = widget.initialMap;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() {
    _search.text = value;
    _map = false;
  });

  Future<void> _locate() async {
    FocusScope.of(context).unfocus();
    setState(() => _map = true);
    final location = context.read<LocationProvider>();
    await location.locate();
    if (!mounted) return;
    if (location.result.state != LocationState.ready) {
      showMessage(context, location.result.message);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapContext = _mapAnchor.currentContext;
      if (mounted && mapContext != null) {
        Scrollable.ensureVisible(
          mapContext,
          duration: const Duration(milliseconds: 300),
          alignment: .15,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final journey = context.watch<JourneyProvider>();
    final location = context.watch<LocationProvider>();
    final area = NearbyArea(
      mode: journey.searchMode,
      devicePosition: location.position,
      pickup: journey.journey?.pickup,
    );
    final catalog = CatalogProvider.of(context);
    final results = Catalog.searchVendorResults(
      _search.text,
      _category,
      area: area,
      vendors: catalog.vendors,
      products: catalog.products,
    );
    final products = Catalog.searchProducts(
      _search.text,
      _category,
      area: area,
      vendors: catalog.vendors,
      products: catalog.products,
    );
    final searching = _search.text.trim().isNotEmpty;
    final available = results.where((r) => r.canSupply).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Find my location',
            onPressed: location.result.state == LocationState.loading
                ? null
                : _locate,
            icon: const Icon(Icons.my_location_rounded),
          ),
          CartButton(),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A little closer to\neverything you need.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 20),
              NearbySearchControls(onLocate: _locate),
              const SizedBox(height: 12),
              LocationPanel(onLocate: _locate, showLocateButton: false),
              CatalogStatus(area: area),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {
                  if (_search.text.trim().isNotEmpty) _map = false;
                }),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'Search medicine, food, essentials…',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => _setQuery(''),
                          icon: Icon(Icons.close),
                        ),
                ),
              ),
              if (!searching) ...[
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final term in ['ORS', 'Idli', 'Water', 'Diapers'])
                      ActionChip(
                        label: Text(term),
                        avatar: Icon(Icons.north_west, size: 14),
                        onPressed: () => _setQuery(term),
                      ),
                  ],
                ),
              ],
              SizedBox(height: 14),
              CategoryFilters(
                selected: _category,
                onSelected: (value) => setState(() => _category = value),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: AppTheme.colors(context).accent,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${area.rangeLabel} from ${area.source}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          area.isPreview
                              ? 'Preview area · enable location or choose a delivery pin'
                              : 'Straight-line distance · vendor inventory',
                          style: TextStyle(
                            color: AppTheme.colors(context).muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: _map ? 'Show list' : 'Show map',
                    onPressed: () => setState(() => _map = !_map),
                    icon: Icon(
                      _map ? Icons.view_list_outlined : Icons.map_outlined,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (searching && results.isNotEmpty)
                Notice(
                  available > 0
                      ? '$available ${available == 1 ? 'shop has' : 'shops have'} matching supplies in stock. Available shops appear first.'
                      : 'No matching supplies are available right now. You can still browse the catalog below.',
                  icon: available > 0
                      ? Icons.check_circle_outline
                      : Icons.inventory_2_outlined,
                ),
              if (_map) ...[
                VendorMap(
                  key: _mapAnchor,
                  vendors: results.map((r) => r.vendor).toList(),
                  area: area,
                  locationRevision: location.fix?.capturedAt,
                ),
                SizedBox(height: 10),
                Text(
                  'All shops within ${area.radiusKm.toInt()} km are included, even shops right beside you.'
                  '${location.position == null ? '' : ' Crosshair: your device location. The smaller circle shows reported GPS accuracy.'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.colors(context).muted,
                  ),
                ),
              ],
              if (!catalog.loading &&
                  catalog.error == null &&
                  results.isEmpty &&
                  products.isEmpty)
                EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Nothing here just yet',
                  message:
                      'No matching shops ${area.distanceLabel}. Try another search, change the journey type, refresh your location or choose a delivery pin.',
                  action: OutlinedButton(
                    onPressed: () => setState(() {
                      _search.clear();
                      _category = null;
                    }),
                    child: Text('Clear filters'),
                  ),
                ),
              if (results.isNotEmpty) ...[
                SectionHeading(
                  searching
                      ? 'Shops with your essentials'
                      : '${results.length} shops around you',
                ),
                for (final result in results)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: VendorCard(
                      key: ValueKey('vendor-${result.vendor.id}'),
                      vendor: result.vendor,
                      highlight: searching && result.canSupply,
                      matchLabel: !searching
                          ? null
                          : !result.vendor.available
                          ? 'Currently closed'
                          : result.inStock.isEmpty
                          ? 'Matching items are out of stock'
                          : '${result.inStock.length} matching ${result.inStock.length == 1 ? 'item' : 'items'} in stock · ${result.inStock.map((p) => p.name).take(2).join(', ')}',
                    ),
                  ),
              ],
              if (products.isNotEmpty) ...[
                SectionHeading('Essentials (${products.length})'),
                if (_category == Category.medicine ||
                    products.any((p) => p.category == Category.medicine) &&
                        searching) ...[
                  Notice(DemoConfig.healthcareNotice),
                  SizedBox(height: 12),
                ],
                for (final product in products)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ProductCard(product: product),
                  ),
              ],
              SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => openPage(context, JourneyScreen()),
                icon: Icon(Icons.edit_location_alt_outlined),
                label: Text('Choose a delivery pin manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
