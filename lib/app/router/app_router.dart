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
import 'package:travla_customer_app/features/marketplace/presentation/new_listing_screen.dart';
import 'package:travla_customer_app/features/more/presentation/more_screen.dart';
import 'package:travla_customer_app/features/news/presentation/news_article_screen.dart';
import 'package:travla_customer_app/features/news/presentation/news_screen.dart';
import 'package:travla_customer_app/features/notifications/presentation/notifications_screen.dart';
import 'package:travla_customer_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:travla_customer_app/features/profile/presentation/profile_screen.dart';
import 'package:travla_customer_app/features/registrations/presentation/new_vehicle_registration_screen.dart';
import 'package:travla_customer_app/features/renewals/presentation/new_renewal_screen.dart';
import 'package:travla_customer_app/features/renewals/presentation/renewal_order_screen.dart';
import 'package:travla_customer_app/features/renewals/presentation/renewals_screen.dart';
import 'package:travla_customer_app/features/transfers/presentation/new_transfer_screen.dart';
import 'package:travla_customer_app/features/transfers/presentation/transfer_detail_screen.dart';
import 'package:travla_customer_app/features/transfers/presentation/transfers_screen.dart';
import 'package:travla_customer_app/features/vehicles/presentation/add_existing_vehicle_screen.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_detail_screen.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicles_screen.dart';
import 'package:travla_customer_app/features/wallet/presentation/transactions_screen.dart';

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
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationsScreen(
          selectedId: state.uri.queryParameters['selected'],
        ),
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
                routes: [
                  GoRoute(
                    path: 'add-existing',
                    builder: (context, state) =>
                        const AddExistingVehicleScreen(),
                  ),
                  GoRoute(
                    path: 'register-new',
                    builder: (context, state) =>
                        const NewVehicleRegistrationScreen(),
                  ),
                  GoRoute(
                    path: ':vehicleId',
                    builder: (context, state) => VehicleDetailScreen(
                      vehicleId: state.pathParameters['vehicleId'] ?? '',
                      initialTab:
                          state.uri.queryParameters['tab'] == 'documents'
                          ? VehicleDetailTab.documents
                          : VehicleDetailTab.overview,
                    ),
                  ),
                ],
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
                path: '/news',
                builder: (context, state) => const NewsScreen(),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (context, state) => NewsArticleScreen(
                      slug: state.pathParameters['slug'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'transactions',
                    builder: (context, state) => const TransactionsScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'renewals',
                    builder: (context, state) => const RenewalsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => NewRenewalScreen(
                          vehicleId: state.uri.queryParameters['vehicle'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: 'orders/:groupId',
                        builder: (context, state) => RenewalOrderScreen(
                          groupId: state.pathParameters['groupId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'marketplace',
                    builder: (context, state) => const MarketplaceScreen(),
                    routes: [
                      GoRoute(
                        path: 'list-new',
                        builder: (context, state) =>
                            NewMarketplaceListingScreen(
                              vehicleId:
                                  state.uri.queryParameters['vehicle'] ?? '',
                            ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'transfers',
                    builder: (context, state) => const TransfersScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => NewTransferScreen(
                          vehicleId: state.uri.queryParameters['vehicle'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: ':transferId',
                        builder: (context, state) => TransferDetailScreen(
                          transferId: state.pathParameters['transferId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
