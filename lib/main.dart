import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'zh_TW';
  await initializeDateFormatting('zh_TW');

  await DatabaseHelper.database;
  await NotificationService.init();

  runApp(const ProviderScope(child: YozeApp()));
}
