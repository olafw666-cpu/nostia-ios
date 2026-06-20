# iOS 2FA (disabled 2026-06-20)

SMS/2FA verification was pulled from the iOS frontend. These files are archived
here (outside the Xcode synchronized group at `NOSTIA/NOSTIA/`, so they are **not
compiled**). The **backend 2FA endpoints remain live** on `appback` — only the
frontend was removed, so re-enabling is mostly a UI restore.

## Files (original locations under `NOSTIA/NOSTIA/`)
- `Network/API/TwoFactorAPI.swift`
- `Views/Auth/TwoFactorChallengeView.swift`
- `Views/Auth/ForgotPasswordView.swift`
- `Views/Auth/TwoFactorComponents.swift`   (OTPField, TwoFactorPrimaryButton, a11yAnnounce, currentDeviceName)
- `Views/Settings/TwoFactorSettingsView.swift`
- `Views/Settings/TwoFactorSetupView.swift`

## To re-enable
1. Move these files back to the matching paths under `NOSTIA/NOSTIA/`.
2. Re-apply the wiring that was reverted in:
   - `Network/API/AuthAPI.swift` — `login` returning `LoginOutcome`, plus `verifyLoginCode` / `resendLoginCode` / `forgotPassword` / `resetPassword` and their response models.
   - `ViewModels/AuthViewModel.swift` — `pendingChallenge` + outcome switch.
   - `Views/Auth/LoginView.swift` — "Forgot password?" link + challenge `fullScreenCover`.
   - `Auth/AuthManager.swift` — `deviceTokenKey` + save/get/deleteDeviceToken.
   - `Views/Privacy/PrivacyView.swift` — Two-Factor Authentication row.
   (See backend commit `3162741` and iOS commit `7cd1528` for the full original diff.)
