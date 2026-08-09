import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/router/customer_shell.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/config/app_launch_controller.dart';
import 'package:travla_customer_app/features/auth/presentation/login_screen.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';
import 'package:travla_customer_app/features/auth/presentation/otp_screen.dart';
import 'package:travla_customer_app/features/auth/presentation/register_screen.dart';
import 'package:travla_customer_app/features/auth/presentation/splash_screen.dart';
import 'package:travla_customer_app/features/home/presentation/home_screen.dart';
import 'package:travla_customer_app/features/journeys/presentation/journeys_screen.dart';
import 'package:travla_customer_app/features/marketplace/presentation/marketplace_screen.dart';
import 'package:travla_customer_app/features/more/presentation/more_screen.dart';
import 'package:travla_customer_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicles_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final phase = ref.watch(
    authControllerProvider.select((session) => session.phase),
  );
  final launchState = ref.watch(appLaunchControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isOnboarding = location == '/onboarding';
      final isRegister = location == '/register';
      final isOtp = location == '/verify-otp';
      final isPublicAuth = isLogin || isRegister || isOtp;

      if (phase == AuthPhase.booting ||
          launchState.phase == AppLaunchPhase.loading) {
        return isSplash ? null : '/splash';
      }

      if (phase == AuthPhase.authenticated) {
        return isSplash || isPublicAuth || isOnboarding ? '/home' : null;
      }

      if (!launchState.onboardingCompleted && !isRegister && !isOtp) {
        return isOnboarding ? null : '/onboarding';
      }

      if (phase == AuthPhase.unauthenticated) {
        return isPublicAuth ? null : '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(
          transferId:
              state.uri.queryParameters['transfer_invitation'] ??
              state.uri.queryParameters['transfer'],
          expires: state.uri.queryParameters['expires'],
          signature: state.uri.queryParameters['signature'],
        ),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final registration = state.extra;
          if (registration is! RegistrationStart) return const LoginScreen();
          return OtpScreen(registration: registration);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CustomerShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vehicles',
                builder: (context, state) => const VehiclesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/journeys',
                builder: (context, state) => const JourneysScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/marketplace',
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
