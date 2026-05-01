import 'package:flutter/material.dart';

import 'app/di/service_locator.dart';
import 'app/invo_print_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  runApp(const InvoPrintApp());
}
