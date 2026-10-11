import '../services/mock_partner_repository.dart';
import '../services/partner_repository.dart';
import 'delivery_partner.dart';
import 'firebase_account.dart';

/// Account identity is real when present; delivery data remains local sample data.
class PartnerSession {
  PartnerSession({this.account, PartnerRepository? repository})
    : repository =
          repository ??
          MockPartnerRepository(
            partner: account == null
                ? const DeliveryPartner()
                : DeliveryPartner(
                    name: account.name?.trim().isNotEmpty == true
                        ? account.name!.trim()
                        : account.email.split('@').first,
                    email: account.email,
                  ),
          );

  final FirebaseAccount? account;
  final PartnerRepository repository;

  bool get isAuthenticated => account != null;
  String get name => repository.partner.name;
  String get accountType => isAuthenticated ? 'Firebase' : 'Demo';
  bool get isOnline => repository.partner.isOnline;
}
