import 'package:flutter/material.dart';

import 'app.dart';
import 'services/firebase_account_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final accounts = await FirebaseAccountGateway.initialize();
  runApp(RouteRescuePartnerApp(accountGateway: accounts));
}
