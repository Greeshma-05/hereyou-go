import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/session_scope.dart';
import '../../services/mock_partner_repository.dart';

bool runDemoAction(BuildContext context, VoidCallback action) {
  try {
    action();
    if (SessionScope.repositoryOf(context).partner.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    return true;
  } on DemoActionException catch (error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  }
}
