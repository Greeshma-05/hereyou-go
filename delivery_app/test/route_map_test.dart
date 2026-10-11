import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/core/theme/app_theme.dart';
import 'package:routerescue_partner/data/demo_data.dart';
import 'package:routerescue_partner/models/route_stop.dart';
import 'package:routerescue_partner/widgets/route_map.dart';

class _TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
}

class _TileImage extends Fake implements TileImage {}

void main() {
  testWidgets(
    'offline diagram selects a request without loading network tiles',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteMap(
                orders: DemoData.requests.take(4).toList(),
                onSelected: (order) => selected = order.id,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(FlutterMap), findsNothing);
      await tester.tap(find.byTooltip('Select RR-2402'));
      await tester.pump();
      expect(selected, 'RR-2402');
      expect(find.text('Offline diagram · Not to scale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tile failure returns to the interactive offline diagram', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RouteMap(
              orders: DemoData.requests.take(1).toList(),
              tileProvider: _TestTiles(),
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    tester.widget<TileLayer>(find.byType(TileLayer)).errorTileCallback!(
      _TileImage(),
      StateError('Offline'),
      StackTrace.current,
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('Street tiles unavailable'), findsOneWidget);
    expect(find.byTooltip('Select RR-2401'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing coordinates keep named stops usable without a map crash',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteMap(
                orders: const [],
                stops: const [
                  RouteStop('Unknown stop', 'Coordinates unavailable'),
                ],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Some route coordinates are missing'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(find.byType(FlutterMap), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
