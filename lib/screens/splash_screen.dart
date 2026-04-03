import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:sharecart/theme/app_decorations.dart';
import 'package:sharecart/theme/app_theme.dart';
import 'package:sharecart/services/auth_service.dart';
import 'list_detail_screen.dart';
import 'lists_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String? _pendingSnackbar;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _navigateAfterSplash();
  }

  Future<void> _handleAddItemDeepLink(Uri? uri) async {
    if (uri == null || uri.scheme != 'sharecart') return;
    if (uri.host != 'add' && !uri.pathSegments.contains('add')) return;
    final listName = uri.queryParameters['list']?.trim();
    final itemName = uri.queryParameters['item']?.trim();
    if (listName == null || listName.isEmpty || itemName == null || itemName.isEmpty) return;
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final result = await AuthService.instance.fetchLists();
      final matches = result.active.where((l) =>
          l.name.toLowerCase().trim() == listName.toLowerCase()).toList();
      if (matches.isNotEmpty) {
        final list = matches.first;
        await AuthService.instance.storeListItem(list.id, itemName, quantity: 1);
        if (mounted) setState(() => _pendingSnackbar = 'Added "$itemName" to $listName');
      }
    } catch (_) {}
  }

  Future<void> _navigateAfterSplash() async {
    await AuthService.instance.loadStoredToken();
    if (AuthService.instance.isLoggedIn) {
      await AuthService.instance.registerFcmTokenWithBackend();
    }
    final appLinks = AppLinks();
    final uri = await appLinks.getInitialLink();
    await _handleAddItemDeepLink(uri);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final isLoggedIn = AuthService.instance.isLoggedIn;
    if (isLoggedIn) {
      final snackbar = _pendingSnackbar;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ListsScreen(initialSnackbar: snackbar),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        ),
        (route) => false,
      );
    } else if (AuthService.instance.isGuestMode && AuthService.instance.guestListId != null) {
      final listId = AuthService.instance.guestListId!;
      // If all items in the list are purchased/completed, show Welcome instead of list
      try {
        final detail = await AuthService.instance.fetchListDetail(listId);
        final allCompleted = detail.items.isNotEmpty &&
            detail.items.every((item) => item.completed);
        if (allCompleted && mounted) {
          await AuthService.instance.clearGuestToken();
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const WelcomeScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
            (route) => false,
          );
          return;
        }
      } catch (_) {
        // On fetch error, still show list (user can retry there)
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ListDetailScreen(
            listId: listId,
            onGuestBack: (ctx) async {
              try {
                await AuthService.instance.leaveList(listId);
              } catch (_) {
                // Leaving shouldn't block navigation.
              }
              await AuthService.instance.clearGuestToken();
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
          ),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        ),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WelcomeScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.pageBackground(),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: AppDecorations.splashLogoCard(primary),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Image.asset(
                        'assets/images/finallogo.png',
                        width: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_cart_rounded,
                          size: 80,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
