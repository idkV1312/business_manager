import 'package:flutter/material.dart';
import 'package:business_manager/core/app/app.dart';
import 'package:business_manager/core/di/app_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppScope(child: const StudioApp()));
}
