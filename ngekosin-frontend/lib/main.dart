import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/auth/auth_state.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await AuthState.instance.restore();
  runApp(const NgekosinApp());
}

class NgekosinApp extends StatelessWidget {
  const NgekosinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ngekos.in',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
