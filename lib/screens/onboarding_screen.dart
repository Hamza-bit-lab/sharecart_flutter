import 'package:concentric_transition/concentric_transition.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sharecart/theme/app_palette.dart';
import 'package:sharecart/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';

const _onboardingCompletedKey = 'onboarding_completed';

Future<bool> hasOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompletedKey) ?? false;
}

Future<void> setOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingCompletedKey, true);
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const List<Color> _pageColors = [
    VintagePalette.blackSoft,
    VintagePalette.yellow,
    VintagePalette.beige,
  ];

  Future<void> _finish(BuildContext context) async {
    await setOnboardingCompleted();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final pages = [
      _OnboardingPageData(
        icon: Icons.people_rounded,
        title: 'onboardingTitle1'.tr,
        description: 'onboardingDesc1'.tr,
        bgColor: _pageColors[0],
        textColor: VintagePalette.yellow,
      ),
      _OnboardingPageData(
        icon: Icons.check_circle_outline_rounded,
        title: 'onboardingTitle2'.tr,
        description: 'onboardingDesc2'.tr,
        bgColor: _pageColors[1],
        textColor: VintagePalette.black,
      ),
      _OnboardingPageData(
        icon: Icons.link_rounded,
        title: 'onboardingTitle3'.tr,
        description: 'onboardingDesc3'.tr,
        bgColor: _pageColors[2],
        textColor: VintagePalette.black,
      ),
    ];

    return Scaffold(
      body: ConcentricPageView(
        itemCount: pages.length,
        colors: pages.map((p) => p.bgColor).toList(),
        radius: screenWidth * 0.1,
        scaleFactor: 2,
        onFinish: () => _finish(context),
        nextButtonBuilder: (_) => Padding(
          padding: const EdgeInsets.only(left: 3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VintagePalette.black.withValues(alpha: 0.88),
              boxShadow: [
                BoxShadow(
                  color: VintagePalette.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.navigate_next,
                size: screenWidth * 0.07,
                color: VintagePalette.yellow,
              ),
            ),
          ),
        ),
        itemBuilder: (index) {
          final page = pages[index % pages.length];
          final isLast = index == pages.length - 1;
          return SafeArea(
            child: _OnboardingPage(
              data: page,
              isLast: isLast,
              getStartedLabel: 'getStarted'.tr,
              onGetStarted: () => _finish(context),
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final Color bgColor;
  final Color textColor;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.bgColor,
    required this.textColor,
  });
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.isLast,
    required this.getStartedLabel,
    required this.onGetStarted,
  });

  final _OnboardingPageData data;
  final bool isLast;
  final String getStartedLabel;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final textColor = data.textColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: textColor.withValues(alpha: 0.15),
          ),
          child: Icon(
            data.icon,
            size: height * 0.12,
            color: textColor,
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            data.title,
            style: TextStyle(
              color: textColor,
              fontSize: height * 0.028,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            data.description,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.9),
              fontSize: height * 0.018,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (isLast) ...[
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onGetStarted,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cta,
                  foregroundColor: AppColors.onCta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  getStartedLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
