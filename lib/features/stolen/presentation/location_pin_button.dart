import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';

/// Captures the device's GPS coordinates — the mobile stand-in for the
/// web stolen-vehicle forms' interactive map pin. Shared between the
/// report-stolen and report-sighting screens.
class LocationPinButton extends StatelessWidget {
  const LocationPinButton({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.busy,
    required this.onTap,
    this.label = 'Pin the exact spot with your current location',
  });

  final double? latitude;
  final double? longitude;
  final bool busy;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pinned = latitude != null && longitude != null;
    return Material(
      color: pinned ? AppColors.forest50 : AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  pinned
                      ? Icons.check_circle_rounded
                      : Icons.my_location_rounded,
                  size: 17,
                  color: pinned ? AppColors.forest700 : AppColors.muted,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pinned
                      ? 'Exact location pinned (${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)})'
                      : label,
                  style: TextStyle(
                    color: pinned ? AppColors.forest800 : AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
