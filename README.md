# Travla Customer App

Flutter customer application for vehicle ownership, vehicle services,
marketplace activity, journeys and fleet participation.

## Application identity

- Android application ID: `ng.com.travla.customer`
- iOS bundle ID: `ng.com.travla.customer`
- API app type: `customer`

## Configuration

The production API is used by default:

```text
https://travla.com.ng/api/v1
```

Override it without committing environment-specific configuration:

```bash
flutter run \
  --dart-define=TRAVLA_API_BASE_URL=https://your-api.example.com/api/v1
```

Android emulators normally reach a locally running API through `10.0.2.2`,
while a physical Android device needs an address it can reach over the same
network or a public HTTPS development endpoint.

## VPS verification policy

The VPS is used for source development and static analysis only:

```bash
flutter analyze
```

Do not install additional Android build tooling or create release builds on
the VPS. Build and run the application after pulling the repository on the
local development PC.

## Current foundation

- Material 3 Travla design system
- Branded native/Flutter splash and persistent first-launch onboarding
- Five-destination customer navigation shell
- API client with `X-App-Type: customer`
- Sanctum bearer-token login and session restoration
- Secure token storage and token-revoking logout
- Live owned/incoming vehicle garage and document-readiness summary
- Android and iOS application scaffolds
