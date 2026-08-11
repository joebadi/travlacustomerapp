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
import 'package:travla_customer_app/features/drivers_license/presentation/add_license_screen.dart';
import 'package:travla_customer_app/features/drivers_license/presentation/drivers_license_screen.dart';
import 'package:travla_customer_app/features/drivers_license/presentation/new_license_renewal_screen.dart';
import 'package:travla_customer_app/features/claims/presentation/claim_detail_screen.dart';
import 'package:travla_customer_app/features/claims/presentation/claims_screen.dart';
import 'package:travla_customer_app/features/claims/presentation/new_claim_screen.dart';
import 'package:travla_customer_app/features/home/presentation/home_screen.dart';
import 'package:travla_customer_app/features/tracking/presentation/live_map_screen.dart';
import 'package:travla_customer_app/features/tracking/presentation/phone_tracker_screen.dart';
import 'package:travla_customer_app/features/stolen/presentation/stolen_screen.dart';
import 'package:travla_customer_app/features/stolen/presentation/report_stolen_screen.dart';
import 'package:travla_customer_app/features/stolen/presentation/stolen_report_detail_screen.dart';
import 'package:travla_customer_app/features/stolen/presentation/report_sighting_screen.dart';
import 'package:travla_customer_app/features/forum/presentation/forum_screen.dart';
import 'package:travla_customer_app/features/forum/presentation/forum_thread_screen.dart';
import 'package:travla_customer_app/features/forum/presentation/new_thread_screen.dart';
import 'package:travla_customer_app/features/fleet/presentation/fleet_screen.dart';
import 'package:travla_customer_app/features/fleet/presentation/create_org_screen.dart';
import 'package:travla_customer_app/features/fleet/presentation/fleet_org_screen.dart';
import 'package:travla_customer_app/features/insurance/presentation/add_policy_screen.dart';
import 'package:travla_customer_app/features/insurance/presentation/buy_insurance_screen.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_screen.dart';
import 'package:travla_customer_app/features/insurance/presentation/new_insurance_renewal_screen.dart';
import 'package:travla_customer_app/features/insurance/presentation/vehicle_insurance_screen.dart';
import 'package:travla_customer_app/features/journeys/presentation/journeys_screen.dart';
import 'package:travla_customer_app/features/journeys/presentation/record_journey_screen.dart';
import 'package:travla_customer_app/features/journeys/presentation/journey_detail_screen.dart';
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
                      initialTab: switch (state.uri.queryParameters['tab']) {
                        'documents' => VehicleDetailTab.documents,
                        'insurance' => VehicleDetailTab.insurance,
                        'tracking' => VehicleDetailTab.tracking,
                        'services' => VehicleDetailTab.services,
                        _ => VehicleDetailTab.overview,
                      },
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
                routes: [
                  GoRoute(
                    path: 'record',
                    builder: (context, state) => const RecordJourneyScreen(),
                  ),
                  GoRoute(
                    path: ':journeyId',
                    builder: (context, state) => JourneyDetailScreen(
                      journeyId: state.pathParameters['journeyId'] ?? '',
                    ),
                  ),
                ],
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
                    path: 'drivers-license',
                    builder: (context, state) => const DriversLicenseScreen(),
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (context, state) => const AddLicenseScreen(),
                      ),
                      GoRoute(
                        path: ':licenseId/renew',
                        builder: (context, state) => NewLicenseRenewalScreen(
                          licenseId: state.pathParameters['licenseId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'insurance',
                    builder: (context, state) => const InsuranceScreen(),
                    routes: [
                      GoRoute(
                        path: ':vehicleId',
                        builder: (context, state) => VehicleInsuranceScreen(
                          vehicleId: state.pathParameters['vehicleId'] ?? '',
                        ),
                        routes: [
                          GoRoute(
                            path: 'add',
                            builder: (context, state) => AddPolicyScreen(
                              vehicleId:
                                  state.pathParameters['vehicleId'] ?? '',
                            ),
                          ),
                          GoRoute(
                            path: 'buy',
                            builder: (context, state) => BuyInsuranceScreen(
                              vehicleId:
                                  state.pathParameters['vehicleId'] ?? '',
                            ),
                          ),
                          GoRoute(
                            path: 'renew/:policyId',
                            builder: (context, state) =>
                                NewInsuranceRenewalScreen(
                                  vehicleId:
                                      state.pathParameters['vehicleId'] ?? '',
                                  policyId:
                                      state.pathParameters['policyId'] ?? '',
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'fleet',
                    builder: (context, state) => const FleetScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const CreateOrgScreen(),
                      ),
                      GoRoute(
                        path: ':orgId',
                        builder: (context, state) => FleetOrgScreen(
                          organisationId: state.pathParameters['orgId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'forum',
                    builder: (context, state) => const ForumScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const NewThreadScreen(),
                      ),
                      GoRoute(
                        path: ':threadId',
                        builder: (context, state) => ForumThreadScreen(
                          threadId: state.pathParameters['threadId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'stolen',
                    builder: (context, state) => const StolenScreen(),
                    routes: [
                      GoRoute(
                        path: 'report',
                        builder: (context, state) => ReportStolenScreen(
                          vehicleId: state.uri.queryParameters['vehicle'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: ':reportId',
                        builder: (context, state) => StolenReportDetailScreen(
                          reportId: state.pathParameters['reportId'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: ':reportId/sighting',
                        builder: (context, state) => ReportSightingScreen(
                          reportId: state.pathParameters['reportId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'tracking',
                    builder: (context, state) => const LiveMapScreen(),
                    routes: [
                      GoRoute(
                        path: 'phone',
                        builder: (context, state) => const PhoneTrackerScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'claims',
                    builder: (context, state) => const ClaimsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => NewClaimScreen(
                          vehicleId: state.uri.queryParameters['vehicle'],
                        ),
                      ),
                      GoRoute(
                        path: ':claimId',
                        builder: (context, state) => ClaimDetailScreen(
                          claimId: state.pathParameters['claimId'] ?? '',
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
