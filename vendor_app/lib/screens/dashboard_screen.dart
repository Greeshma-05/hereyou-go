import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/core/utils/formatters.dart';
import 'package:route_rescue/core/utils/navigation.dart';
import 'package:route_rescue/widgets/common.dart';
import '../state/merchant_state.dart';
import 'shop_editor.dart';
import 'product_editor.dart';
import 'orders_screen.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.fulfillment});
  final FulfillmentRepository? fulfillment;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _query = '';
  String _filter = 'All';
  Future<void> _logout() async {
    try {
      await context.read<MerchantState>().repository.signOut();
    } catch (e) {
      if (mounted) showMessage(context, merchantError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MerchantState>();
    if (state.loading) {
      return const Scaffold(body: LoadingView(message: 'Loading your shop…'));
    }
    if (state.shop == null && state.error == null) return const ShopEditor();
    final shop = state.shop;
    final items = state.products
        .where(
          (p) =>
              '${p.name} ${p.genericName} ${p.brand} ${p.strength ?? ''}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()) &&
              (_filter == 'All' ||
                  _filter == 'Published' && p.published ||
                  _filter == 'Hidden' && !p.published),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your shop'),
        actions: [
          if (shop != null)
            IconButton(
              tooltip: 'Edit shop',
              onPressed: () => openPage(context, ShopEditor(shop: shop)),
              icon: const Icon(Icons.storefront_outlined),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null) ...[
                Notice(state.error!, warning: true),
                TextButton(
                  onPressed: state.connect,
                  child: const Text('Retry shop connection'),
                ),
              ],
              if (shop != null) ...[
                const StatusBadge(text: 'HERE YOU GO · VENDOR'),
                const SizedBox(height: 14),
                Text(
                  shop.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(shop.area),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      text: shop.published ? 'SHOP PUBLISHED' : 'SHOP HIDDEN',
                    ),
                    StatusBadge(text: shop.available ? 'OPEN' : 'CLOSED'),
                    StatusBadge(
                      text:
                          '${state.products.length} ${state.products.length == 1 ? 'PRODUCT' : 'PRODUCTS'}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Shop pin: ${shop.position.latitude.toStringAsFixed(5)}, ${shop.position.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        openPage(context, ProductEditor(shop: shop)),
                    icon: const Icon(Icons.add),
                    label: const Text('Add product'),
                  ),
                ),
                if (widget.fulfillment != null) ...[
                  const SizedBox(height: 12),
                  VendorOrdersButton(
                    repository: widget.fulfillment!,
                    uid: state.uid,
                  ),
                ],
                const SectionHeading('Your inventory'),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search your products',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final filter in ['All', 'Published', 'Hidden'])
                      ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        labelStyle: TextStyle(
                          color: _filter == filter
                              ? AppTheme.colors(context).onAccent
                              : AppTheme.colors(context).ink,
                        ),
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (state.inventoryLoading) const Text('Loading inventory…'),
                if (!state.inventoryLoading && items.isEmpty)
                  const Notice(
                    'No products here yet. Add your first product or change the filter.',
                  ),
                for (final p in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit ${p.name}',
                                  onPressed: () => openPage(
                                    context,
                                    ProductEditor(shop: shop, product: p),
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                            if (p.strength != null)
                              Text('${p.strength} · ${p.dosageForm}'),
                            Text(
                              '${money(p.pricePaise)} · ${p.unit}',
                              style: TextStyle(
                                color: AppTheme.colors(context).accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                StatusBadge(
                                  text: !p.published
                                      ? 'HIDDEN'
                                      : p.expired
                                      ? 'EXPIRED'
                                      : p.stock == 0
                                      ? 'SOLD OUT'
                                      : '${p.stock} IN STOCK',
                                ),
                                if (p.prescriptionRequired)
                                  const StatusBadge(
                                    text: 'PRESCRIPTION REQUIRED',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Notice(
                  'Customers within 7 km for buses or 20 km for trains can see your published products. Price and stock changes update automatically. Customer orders are paid in cash on delivery. Manage them in Customer orders.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
