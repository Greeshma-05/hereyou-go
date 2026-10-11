import 'package:flutter/widgets.dart';

import '../models/partner_session.dart';
import '../services/partner_repository.dart';

// Delivery state lives in memory; the Firebase SDK manages authentication tokens.
class SessionScope extends InheritedNotifier<PartnerRepository> {
  SessionScope({required this.session, required super.child, super.key})
    : super(notifier: session.repository);

  final PartnerSession session;

  static PartnerSession? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()?.session;
  }

  static PartnerRepository repositoryOf(BuildContext context) =>
      maybeOf(context)!.repository;
}
