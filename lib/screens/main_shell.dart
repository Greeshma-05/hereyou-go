import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/navigation.dart';
import '../providers/cart_provider.dart';
import 'cart/cart_screen.dart';
import 'explore/explore_screen.dart';
import 'home/home_screen.dart';
import 'orders/orders_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selected = 0;
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final stackNavigation =
        AppTheme.readingFont(context) ||
        MediaQuery.textScalerOf(context).scale(12) > 16;
    return Scaffold(
      body: switch (_selected) {
        0 => HomeScreen(
          onProfile: () => setState(() => _selected = 3),
          onExplore: () => setState(() => _selected = 1),
        ),
        1 => ExploreScreen(),
        2 => OrdersScreen(),
        _ => ProfileScreen(),
      },
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!cart.isEmpty)
            Material(
              color: AppTheme.colors(context).accent,
              child: InkWell(
                onTap: () => openPage(context, CartScreen()),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: AppTheme.colors(context).onAccent,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${cart.count} item${cart.count == 1 ? '' : 's'} · ${money(cart.totalPaise)}',
                          style: TextStyle(
                            color: AppTheme.colors(context).onAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'View bag',
                        style: TextStyle(
                          color: AppTheme.colors(context).onAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward,
                        color: AppTheme.colors(context).onAccent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              margin: EdgeInsets.fromLTRB(16, 10, 16, 12),
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.colors(context).elevated,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: AppTheme.colors(context).border),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      flex: _selected == i ? 2 : 1,
                      child: Tooltip(
                        message: ['Home', 'Explore', 'Orders', 'Profile'][i],
                        child: Semantics(
                          selected: _selected == i,
                          button: true,
                          label: ['Home', 'Explore', 'Orders', 'Profile'][i],
                          excludeSemantics: true,
                          child: Material(
                            color: _selected == i
                                ? AppTheme.colors(context).accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () => setState(() => _selected = i),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 3,
                                ),
                                child: Flex(
                                  direction: stackNavigation
                                      ? Axis.vertical
                                      : Axis.horizontal,
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      [
                                        Icons.home_outlined,
                                        Icons.explore_outlined,
                                        Icons.receipt_long_outlined,
                                        Icons.person_outline,
                                      ][i],
                                      size: 21,
                                      color: _selected == i
                                          ? AppTheme.colors(context).onAccent
                                          : AppTheme.colors(context).muted,
                                    ),
                                    if (_selected == i) ...[
                                      SizedBox(
                                        width: stackNavigation ? 0 : 6,
                                        height: stackNavigation ? 4 : 0,
                                      ),
                                      Flexible(
                                        child: Text(
                                          [
                                            'Home',
                                            'Explore',
                                            'Orders',
                                            'Profile',
                                          ][i],
                                          textAlign: TextAlign.center,
                                          maxLines: stackNavigation ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.colors(
                                              context,
                                            ).onAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
