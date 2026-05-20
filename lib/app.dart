import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/photo_capture_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/user_guide_screen.dart';
import 'screens/verification_screen.dart';

class YozeApp extends StatelessWidget {
  const YozeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOZE 藥師',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/setup':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => VerificationScreen(
                imagePath: args?['imagePath'] as String?,
                startWithCamera: args?['startWithCamera'] as bool? ?? false,
              ),
            );
          case '/history':
            return MaterialPageRoute(builder: (_) => const HistoryScreen());
          case '/guide':
            return MaterialPageRoute(builder: (_) => const UserGuideScreen());
          case '/capture':
            return MaterialPageRoute(
              builder: (_) => const PhotoCaptureScreen(),
            );
          case '/processing':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ProcessingScreen(
                imagePath: args?['imagePath'] ?? '',
                returnExtractedMedications:
                    args?['returnExtractedMedications'] as bool? ?? false,
              ),
            );
          case '/verify':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) =>
                  VerificationScreen(imagePath: args?['imagePath'] ?? ''),
            );
          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
