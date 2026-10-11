import 'package:flutter/material.dart';

import '../../providers/session_scope.dart';

abstract final class PartnerNavigation {
  static Future<T?> open<T>(BuildContext context, Widget screen) {
    final session = SessionScope.maybeOf(context)!;
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => SessionScope(session: session, child: screen),
      ),
    );
  }
}
