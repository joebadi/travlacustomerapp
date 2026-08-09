import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/config/app_launch_controller.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      eyebrow: 'YOUR VEHICLE WORKSPACE',
      title: 'Every vehicle.\nOne clear account.',
      description:
          'Keep vehicles, papers, ownership records and service activity organised wherever you are.',
      illustration: _IllustrationType.vehicles,
    ),
    _OnboardingPageData(
      eyebrow: 'PAPER READINESS',
      title: 'Stay ahead of\nevery renewal.',
      description:
          'Know what is valid, expiring or overdue, then begin the right renewal without starting from scratch.',
      illustration: _IllustrationType.renewals,
    ),
    _OnboardingPageData(
      eyebrow: 'CONNECTED MOBILITY',
      title: 'Ownership and\nevery journey, connected.',
      description:
          'Handle transfers and trusted transactions, record useful routes and participate in a fleet from the same app.',
      illustration: _IllustrationType.connected,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await ref.read(appLaunchControllerProvider.notifier).completeOnboarding();
  }

  Future<void> _skip() {
    return ref.read(appLaunchControllerProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 14, 4),
              child: Row(
                children: [
                  const TravlaLogo(width: 128),
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(_pages.length, (index) {
                        final selected = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: selected ? 30 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.orange
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(150, 54),
                      backgroundColor: isLastPage
                          ? AppColors.orange
                          : AppColors.forest800,
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: Icon(
                      isLastPage
                          ? Icons.login_rounded
                          : Icons.arrow_forward_rounded,
                      size: 19,
                    ),
                    label: Text(isLastPage ? 'Go to sign in' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualHeight = math.min(300.0, constraints.maxHeight * .52);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: visualHeight,
                width: double.infinity,
                child: _OnboardingIllustration(type: data.illustration),
              ),
              const SizedBox(height: 26),
              Text(
                data.eyebrow,
                style: const TextStyle(
                  color: AppColors.forest600,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.25,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                data.title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 36,
                  height: 1.06,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  data.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.muted,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.type});

  final _IllustrationType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -48,
            top: -55,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .08),
                  width: 38,
                ),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -80,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withValues(alpha: .07),
              ),
            ),
          ),
          Center(child: _illustrationContent()),
        ],
      ),
    );
  }

  Widget _illustrationContent() {
    return switch (type) {
      _IllustrationType.vehicles => const _VehicleVisual(),
      _IllustrationType.renewals => const _RenewalVisual(),
      _IllustrationType.connected => const _ConnectedVisual(),
    };
  }
}

class _VehicleVisual extends StatelessWidget {
  const _VehicleVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(-42, -28),
          child: const _VisualCard(
            width: 175,
            icon: Icons.description_outlined,
            label: 'Vehicle papers',
            accent: AppColors.forest100,
          ),
        ),
        Transform.translate(
          offset: const Offset(36, 40),
          child: const _VisualCard(
            width: 190,
            icon: Icons.directions_car_filled_rounded,
            label: 'My vehicles',
            accent: AppColors.orangeSoft,
            highlighted: true,
          ),
        ),
      ],
    );
  }
}

class _RenewalVisual extends StatelessWidget {
  const _RenewalVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 225,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: AppColors.forest600),
              Spacer(),
              Text(
                'READINESS',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Vehicle licence',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 7),
          const Text(
            'Renewal due in 21 days',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: .78,
              minHeight: 7,
              color: AppColors.orange,
              backgroundColor: AppColors.orangeSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedVisual extends StatelessWidget {
  const _ConnectedVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.alt_route_rounded,
            color: AppColors.white,
            size: 42,
          ),
        ),
        ...const [
          _OrbitBadge(
            offset: Offset(-102, -62),
            icon: Icons.swap_horiz_rounded,
            label: 'Transfers',
          ),
          _OrbitBadge(
            offset: Offset(103, -55),
            icon: Icons.storefront_outlined,
            label: 'Marketplace',
          ),
          _OrbitBadge(
            offset: Offset(0, 94),
            icon: Icons.business_outlined,
            label: 'Fleet',
          ),
        ],
      ],
    );
  }
}

class _OrbitBadge extends StatelessWidget {
  const _OrbitBadge({
    required this.offset,
    required this.icon,
    required this.label,
  });

  final Offset offset;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppColors.forest700, size: 23),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualCard extends StatelessWidget {
  const _VisualCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.accent,
    this.highlighted = false,
  });

  final double width;
  final IconData icon;
  final String label;
  final Color accent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFDFDFD) : const Color(0xFFEFF6F3),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.forest800, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

enum _IllustrationType { vehicles, renewals, connected }

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.illustration,
  });

  final String eyebrow;
  final String title;
  final String description;
  final _IllustrationType illustration;
}
