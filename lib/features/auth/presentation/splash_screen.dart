import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _markFade;
  late final Animation<double> _markScale;
  late final Animation<double> _wordmarkFade;
  late final Animation<Offset> _wordmarkSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _markFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .55, curve: Curves.easeOut),
    );
    _markScale = Tween<double>(begin: .86, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, .68, curve: Curves.easeOutBack),
      ),
    );
    _wordmarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.26, .86, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(begin: const Offset(0, .3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(.24, .9, curve: Curves.easeOutCubic),
          ),
        );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forest950,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.forest950,
                  Color(0xFF07523B),
                  AppColors.forest900,
                  Color(0xFF031F17),
                ],
                stops: [0, .4, .73, 1],
              ),
            ),
          ),
          const CustomPaint(painter: _SplashRoadPainter()),
          Positioned(
            top: -165,
            right: -135,
            child: _GlowCircle(
              size: 360,
              color: AppColors.forest600.withValues(alpha: .18),
            ),
          ),
          Positioned(
            bottom: -210,
            left: -180,
            child: _GlowCircle(
              size: 430,
              color: AppColors.orange.withValues(alpha: .055),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'CUSTOMER APP',
                      style: TextStyle(
                        color: Color(0xFF90B7A8),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _markFade,
                            child: ScaleTransition(
                              scale: _markScale,
                              child: Image.asset(
                                'assets/brand/travla-mark-white.png',
                                width: 150,
                                height: 150,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                semanticLabel: 'Travla road logo',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FadeTransition(
                            opacity: _wordmarkFade,
                            child: SlideTransition(
                              position: _wordmarkSlide,
                              child: const Column(
                                children: [
                                  TravlaLogo(onDark: true, width: 205),
                                  SizedBox(height: 17),
                                  _BrandRule(),
                                  SizedBox(height: 15),
                                  Text(
                                    'YOUR VEHICLE. ONE ACCOUNT.',
                                    style: TextStyle(
                                      color: Color(0xFF9AB9AD),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 126,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.orange,
                      backgroundColor: Color(0xFF345A4D),
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Preparing your Travla workspace',
                    style: TextStyle(
                      color: Color(0xFF86A99C),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandRule extends StatelessWidget {
  const _BrandRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 28, height: 1, color: const Color(0xFF5B8274)),
        const SizedBox(width: 8),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 28, height: 1, color: const Color(0xFF5B8274)),
      ],
    );
  }
}

class _SplashRoadPainter extends CustomPainter {
  const _SplashRoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final lanePaint = Paint()
      ..color = AppColors.orange.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final leftEdge = Path()
      ..moveTo(-size.width * .18, size.height)
      ..cubicTo(
        size.width * .24,
        size.height * .78,
        size.width * .33,
        size.height * .51,
        size.width * .44,
        -20,
      );
    final rightEdge = Path()
      ..moveTo(size.width * 1.18, size.height)
      ..cubicTo(
        size.width * .76,
        size.height * .78,
        size.width * .67,
        size.height * .51,
        size.width * .56,
        -20,
      );
    final lane = Path()
      ..moveTo(size.width * .5, size.height * 1.04)
      ..cubicTo(
        size.width * .5,
        size.height * .72,
        size.width * .5,
        size.height * .4,
        size.width * .5,
        -20,
      );

    canvas.drawPath(leftEdge, edgePaint);
    canvas.drawPath(rightEdge, edgePaint);
    canvas.drawPath(lane, lanePaint);
  }

  @override
  bool shouldRepaint(covariant _SplashRoadPainter oldDelegate) => false;
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 58),
      ),
    );
  }
}
