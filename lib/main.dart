import 'package:business_manager/core/app/app.dart';
import 'package:flutter/material.dart';
import 'package:business_manager/core/di/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.init();
  runApp(AppScope(controller: controller, child: const StudioApp()));
}
