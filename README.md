# Nostia iOS (Native SwiftUI)

Native iOS app built with SwiftUI + async/await. Mirrors the Expo app exactly.

## Xcode Setup (do this on your Mac)

### 1. Create the Xcode project
- Open Xcode → **File → New → Project**
- Choose **iOS → App**
- Settings:
  - Product Name: `Nostia`
  - Bundle Identifier: `PLACEHOLDER_IOS_BUNDLE_ID` ← **replace with your Apple bundle ID**
  - Interface: SwiftUI
  - Language: Swift
  - Uncheck "Include Tests" (optional)
- Save it **inside** `nostia-ios/` so files sit alongside this README

### 2. Delete auto-generated files
Delete Xcode's default `ContentView.swift` — all views are in `NostiaApp/Views/`.

### 3. Add source files to Xcode
- In Xcode's file navigator, right-click the project → **Add Files to "Nostia"**
- Select the entire `NostiaApp/` folder
- Check **"Create groups"** and **"Add to target: Nostia"**
- Click **Add**

### 4. Add Swift Package Dependencies
**File → Add Package Dependencies** (or in project settings → Package Dependencies tab):

| Package | URL | Product to add |
|---|---|---|
| Stripe iOS | `https://github.com/stripe/stripe-ios-spm` | `StripePaymentSheet` |

No other external packages needed — everything else uses Apple frameworks (URLSession, MapKit, CoreLocation, Security).

### 5. Configure Info.plist
The `NostiaApp/Info.plist` file is already included. In Xcode:
- Select your target → **Info** tab
- Verify `NSLocationWhenInUseUsageDescription` is present

### 6. Register Bundle ID in Apple Developer
- Go to [developer.apple.com](https://developer.apple.com) → Identifiers
- Create an App ID matching your bundle identifier
- Enable **Maps** and **Push Notifications** capabilities

### 7. Build & Run
- Select your device or simulator
- **Product → Build** (⌘B) — fix any compile errors
- **Product → Run** (⌘R)

---

## Known TODOs before App Store submission

- [ ] **Bundle ID**: Replace `PLACEHOLDER_IOS_BUNDLE_ID` in `AppConfig.swift` and Xcode project settings with your real Apple bundle ID (e.g. `com.nostia.app`)
- [ ] **App Icon**: Add your icon set to `Assets.xcassets/AppIcon`
- [ ] **Splash Screen**: Configure `LaunchScreen.storyboard` or use a SwiftUI launch screen
- [ ] **Push Notifications**: Register for remote notifications in `NostiaApp.swift`, save token via `NotificationsAPI.shared.savePushToken()`
- [ ] **Analytics Screen**: Hidden in UI by default — accessible only for admin users (same as Expo)

---

## Architecture

```
NostiaApp/
├── NostiaApp.swift          ← App entry, Stripe init
├── Config/
│   └── AppConfig.swift      ← API URL, Stripe key (no secrets)
├── Auth/
│   └── AuthManager.swift    ← JWT in Keychain (Security framework)
├── Location/
│   └── LocationManager.swift ← CLLocationManager wrapper
├── Network/
│   ├── APIClient.swift      ← URLSession + async/await
│   ├── APIError.swift
│   └── API/                 ← One file per API domain
├── Models/                  ← Codable structs
├── ViewModels/              ← @MainActor ObservableObject
├── Views/
│   ├── RootView.swift       ← Auth vs Main conditional
│   ├── MainTabView.swift    ← TabView (5 tabs + notification/settings sheets)
│   ├── Auth/                ← LoginView, SignupView
│   ├── Home/                ← HomeView
│   ├── Trips/               ← TripsView, VaultView (navigated from trips)
│   ├── Friends/             ← FriendsView, FriendsMapView (MapKit)
│   ├── Adventures/          ← AdventuresView (events + adventures)
│   ├── Chat/                ← ChatView (polling every 5s)
│   ├── Notifications/       ← NotificationsView
│   ├── Privacy/             ← PrivacyView (settings + logout)
│   └── Components/          ← SharedComponents.swift (Avatar, Loading, Consent, CreateTrip, CreateExpense sheets)
└── Extensions/
    └── Color+Hex.swift      ← Design tokens matching Expo dark theme
```

## API
- **Base URL**: `https://king-prawn-app-44tki.ondigitalocean.app/api`
- **Auth**: JWT Bearer token stored in Keychain via Security framework
- **Token expiry**: 7 days (matches backend)

## Stripe
- **Publishable key**: Set in `AppConfig.swift`
- **Flow**: `VaultViewModel.preparePaymentSheet()` fetches client secret → presents `PaymentSheet` → result handled by `handlePaymentResult()`
- **Package**: `stripe-ios-spm` → add `StripePaymentSheet` target in Xcode
