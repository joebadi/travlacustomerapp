import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/auth/domain/app_user.dart';

/// The user's circular avatar — their profile photo, or their initials on a
/// tinted background when there is none. Shared by the account menu and the
/// bottom-nav Profile tab icon.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.user, required this.radius});

  final AppUser? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = user?.profileImageUrl?.trim() ?? '';
    final size = radius * 2;

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.forest100,
        child: imageUrl.isEmpty
            ? _Initials(name: user?.fullName, fontSize: radius * .72)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _Initials(name: user?.fullName, fontSize: radius * .72),
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.fontSize});

  final String? name;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final words = (name ?? '').trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return Center(
      child: Text(
        initials.isEmpty ? 'T' : initials,
        style: TextStyle(
          color: AppColors.forest800,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
