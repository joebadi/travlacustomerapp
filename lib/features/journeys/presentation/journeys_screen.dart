import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/shared/widgets/section_heading.dart';

class JourneysScreen extends StatelessWidget {
  const JourneysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journeys')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const SectionHeading(
            title: 'Move with a dependable trail',
            description:
                'Record routes, follow saved trails and receive useful road intelligence.',
          ),
          const SizedBox(height: 22),
          Container(
            height: 230,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.forest950, AppColors.forest700],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  bottom: -28,
                  child: Icon(
                    Icons.route_rounded,
                    size: 180,
                    color: Colors.white.withValues(alpha: .07),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation_outlined,
                        color: AppColors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Journey engine foundation',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Map, background location and offline trail storage will be enabled after the device spike.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .68),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _JourneyCapability(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Saved trails',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _JourneyCapability(
                  icon: Icons.report_gmailerrorred_outlined,
                  label: 'Road reports',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyCapability extends StatelessWidget {
  const _JourneyCapability({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.forest700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
