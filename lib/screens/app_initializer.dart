import 'package:flutter/material.dart';
import 'package:sharecart/theme/app_palette.dart';
import 'package:sharecart/screens/onboarding_screen.dart';
import 'splash_screen.dart';

/// Decides whether to show onboarding (first launch) or splash.
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final completed = await hasOnboardingCompleted();
    if (mounted) {
      setState(() => _showOnboarding = !completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return Scaffold(
        backgroundColor: VintagePalette.beige,
        body: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return _showOnboarding! ? const OnboardingScreen() : const SplashScreen();
  }
}
