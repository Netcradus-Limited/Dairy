# Sawariya Dairy â€” Android Runtime Verification Report

**Application:** Sawariya Dairy (`com.sawariyassarkar.app`)
**Firebase Project:** `sawariya-7efd4` (Android App ID: `1:325042169664:android:56d2e62240c424841d7ca5`)
**Version Audited:** `1.0.6+6` (`versionCode = 6`, `versionName = 1.0.6`)
**Audit Mode:** Verification-only (`ANDROID_RUNTIME_VERIFICATION_REPORT.md` only; zero source, Gradle, Manifest, Firebase, Cloud Functions, signing, or AAB modifications).
**Final Release Recommendation:** **`INCOMPLETE`** *(Preflight blocked â€” zero physical Android devices attached, target API 29â€“36 environments absent, and QA APK debug signing certificates unregistered in Firebase.)*

---

## 1. Device Inventory

Checked via `C:\Users\Dell\AppData\Local\Android\sdk\platform-tools\adb.exe devices -l` and `C:\Users\Dell\AppData\Local\Android\sdk\emulator\emulator.exe -list-avds`:

| Target | Device ID / Name | Android Version / API | Manufacturer / Model | State | Preflight Result |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Physical Android Devices | *None* (`List of devices attached` empty) | â€” | â€” | Not connected | **BLOCKED** |
| Configured AVD #1 | `Medium_Phone` | System image: `android-37.1` (`google_apis_playstore_ps16k\x86_64`) | Emulator AVD | Stopped (off-matrix API) | **OFF-MATRIX** (target matrix requires API 29, 30â€“32, 33, 34, 35â€“36) |

No dedicated test device or API 29â€“36 Android emulator was available for APK installation or execution.

---

## 2. APK Identity, Permissions & SHA-256

### QA APK (`C:\Desktop\dairy\Dairy\build\app\outputs\apk\qa\app-qa.apk`)
Inspected with `Get-FileHash`, `build-tools\36.0.0\aapt2.exe dump badging`, and `build-tools\36.0.0\apksigner.bat verify --print-certs`:

- **SHA-256:** `12A6109D316EF50746780CE00C7EC4C35B397658850AD14C180FD46A8D1BBC6B`
- **Package Name:** `com.sawariyassarkar.app`
- **Version:** `versionCode='6'`, `versionName='1.0.6'`
- **SDK Targets:** `minSdkVersion='24'`, `targetSdkVersion='36'`, `compileSdkVersion='36'` (`Android 16`)
- **Signing Certificate (`Signer #1`):**
  - DN: `C=US, O=Android, CN=Android Debug`
  - **SHA-1:** `69cdc1c676b8d8019523b6d4955e6be9e3e893ae`
  - **SHA-256:** `f2842fbfc27f0b86c09cb3852a40dd9d431dc62e389d5d428a161d8bcc7d84bd`
- **Declared Permissions Confirmed via `aapt2 dump badging`:**
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.ACCESS_COARSE_LOCATION`
  - `android.permission.ACCESS_BACKGROUND_LOCATION`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_LOCATION`
  - `android.permission.POST_NOTIFICATIONS`
  - `android.permission.WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `VIBRATE`, `C2DM.RECEIVE`, `READ_GSERVICES`
  - Confirmed `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is **absent**.

### Submitted Production AAB (Unchanged)
- **File:** `C:\Desktop\dairy\Dairy\build\app\outputs\bundle\release\app-release.aab`
- **SHA-256:** `DF28AC8DF8D98E03BD565886583B93D886FE0E9D426F81C65D4AB78E12223EC5` *(verified intact; untouched)*

---

## 3. Firebase Authentication & Debug SHA Preflight Results

Checked via read-only CLI command:
```powershell
firebase.cmd apps:android:sha:list 1:325042169664:android:56d2e62240c424841d7ca5 --project sawariya-7efd4
```

- **Registered Firebase SHA Hashes (`1` total):**
  - `SHA_256`: `0c3c980a099ae19e3dbeb4ba76ba41793c97a8f9a4be8191d0a854a8f37b8aab` *(release/upload key)*
- **QA APK Debug Key Hashes (`NOT REGISTERED`):**
  - Debug SHA-1 (`69cdc1c676b8d8019523b6d4955e6be9e3e893ae`): **Absent**
  - Debug SHA-256 (`f2842fbfc27f0b86c09cb3852a40dd9d431dc62e389d5d428a161d8bcc7d84bd`): **Absent**
- **Impact:** Live Customer login, Delivery Partner Phone OTP login, and Play Integrity hardware token exchange on `app-qa.apk` are **NOT VERIFIED / BLOCKED** until either the Debug SHA-1/SHA-256 fingerprints are registered in Firebase Console for QA testing or Firebase fallback/App Check behavior is tested with a registered key.

---

## 4. Ten Runtime Test Results (Phase 3)

Per safety rule **#8 ("Do not mark a test PASS without actual device evidence")**, all 10 runtime compliance tests are recorded as **`NOT VERIFIED`** because Phase 1 preflight failed (zero connected devices; target APIs missing; debug SHA unregistered):

| # | Test Scenario | Preconditions / Actions / Expected | Actual Behavior | Evidence | Status |
| :- | :--- | :--- | :--- | :--- | :- |
| **1** | Foreground permission rationale & OS permission dialog | Not executed â€” 0 ADB devices connected | Not executed | None | **NOT VERIFIED** |
| **2** | Disclosure acceptance and rejection (`Agree & Continue` vs `Not Now`) | Not executed â€” 0 ADB devices connected | Not executed | None | **NOT VERIFIED** |
| **3** | Background location permission (Android 10 vs Android 11+) | Not executed â€” API 29 & API 30+ hardware/emulators absent | Not executed | None | **NOT VERIFIED** |
| **4** | Android 13+ notification permission granted & denied | Not executed â€” API 33+ device/emulator absent | Not executed | None | **NOT VERIFIED** |
| **5** | Tracking while app minimized & screen locked | Not executed â€” 0 ADB devices connected | Not executed | None | **NOT VERIFIED** |
| **6** | Offline, Break, Logout & Order completion lifecycle | Not executed â€” 0 ADB devices connected & Firebase Auth preflight blocked | Not executed | None | **NOT VERIFIED** |
| **7** | Android process termination (`am kill` / LMK) | Not executed â€” 0 ADB devices connected | Not executed | None | **NOT VERIFIED** |
| **8** | Android 13+ Foreground Service Task Manager Stop | Not executed â€” API 33+ device/emulator absent | Not executed | None | **NOT VERIFIED** |
| **9** | Force Stop (`App Info > Force stop`) & subsequent relaunch | Not executed â€” 0 ADB devices connected | Not executed | None | **NOT VERIFIED** |
| **10** | Location permission revocation & downgrade via Android Settings | Not executed â€” 0 ADB devices connected | Not executed | None | **NOT VERIFIED** |

---

## 5. API-Level Coverage (Phase 5)

| API Bucket | Android Version(s) | Device / Emulator Available | Runtime Status |
| :--- | :--- | :--- | :--- |
| **API 29** | Android 10 | None | **NOT VERIFIED** |
| **API 30â€“32** | Android 11â€“12L | None | **NOT VERIFIED** |
| **API 33** | Android 13 | None | **NOT VERIFIED** |
| **API 34** | Android 14 | None | **NOT VERIFIED** |
| **API 35â€“36** | Android 15â€“16 | None (`Medium_Phone` has stopped `android-37.1` image only) | **NOT VERIFIED** |

No API level's runtime behavior has been inferred from another API level or from automated Flutter unit tests.

---

## 6. Screenshots & Video Evidence Locations

- **Collected:** None (`0` files). Preflight blocked before Phase 2 APK installation.

---

## 7. Logcat Findings

- **Collected:** None. No `adb install`, app launch, OS permission dialog, `GeolocatorLocationService` foreground start, or Phone Auth verification occurred on hardware.

---

## 8. Firestore Tracking Evidence

- **Live Android Runtime Writes / Revocation:** **NOT VERIFIED** (no QA APK installed or executed on Android hardware).
- *(Pre-existing automated emulator checks and Flutter unit tests remain documented separately; they do not substitute for real Android device evidence.)*

---

## 9. Blockers & Bugs Discovered

1. **Preflight Blocker 1 â€” Missing Android Runtime Hardware / Matrix Emulators:**
   `adb devices -l` reported zero connected Android phones and zero active emulators. Local Android SDK `system-images` contains only `android-37.1` (`Medium_Phone`, stopped), leaving **API 29, 30â€“32, 33, 34, and 35â€“36** completely unprovisioned.
2. **Preflight Blocker 2 â€” QA APK Debug Certificates Unregistered in Firebase (`sawariya-7efd4`):**
   `firebase.cmd apps:android:sha:list` confirms only release `SHA_256` `0c3c980a099ae19e3dbeb4ba76ba41793c97a8f9a4be8191d0a854a8f37b8aab` is registered. Installing debug-signed `app-qa.apk` (SHA-1 `69cdc1c676b8d8019523b6d4955e6be9e3e893ae`, SHA-256 `f2842fbfc27f0b86c09cb3852a40dd9d431dc62e389d5d428a161d8bcc7d84bd`) without registering these hashes in Firebase Console can block Play Integrity / Phone OTP verification in Phase 2.
3. **Application Source Code Bugs:** No new source code bugs were observed because runtime execution could not begin past Phase 1.

---

## 10. Unverified Scenarios (Phases 2â€“5)

All runtime Android verification scenarios remain **`NOT VERIFIED`**:
- **Phase 2:** Safe QA APK install on dedicated test device, Customer login & Delivery Partner Phone OTP login, Firestore live connectivity, Customer foreground location isolation (`Use Current Location` without background disclosure), and Logcat inspection.
- **Phase 3:** Tests 1â€“10 listed in Section 4.
- **Phase 4:** Live verification on device with persisted `isOnline: true` in Firestore, pre-disclosure background isolation, `Not Now` foreground-only degradation, Offline/Break/Logout/Delivered `orderId` cleanup, cross-customer isolation against production-like rules, Android 13+ notification denial banner + settings navigation, and OS stream termination non-restart.
- **Phase 5:** Full 5-bucket API matrix (`API 29`, `30â€“32`, `33`, `34`, `35â€“36`).

---

## 11. Final Release Recommendation

### **`INCOMPLETE`**

**Reason:** Phase 1 Device & APK Preflight stopped due to two environment/configuration blockers:
1. No physical Android device or target API (29, 30â€“32, 33, 34, 35â€“36) emulator is connected/provisioned.
2. The `app-qa.apk` debug keystore SHA-1/SHA-256 certificates are not registered on Firebase project `sawariya-7efd4`.

**Required Actions to Unblock Phase 2â€“5 Verification (Zero Code Edits Required):**
1. Connect dedicated Android test device(s) via USB Debugging (spanning API 29, 30â€“32, 33, 34, 35â€“36) or provision target API emulators with Google Play APIs + location mock support (`adb devices` non-empty).
2. In Firebase Console (`sawariya-7efd4` â†’ Project Settings â†’ Android App `1:325042169664:android:56d2e62240c424841d7ca5`), register the QA debug certificate fingerprints (with explicit authorization) or use Firebase Phone Auth test numbers / QA-signed build before running Phase 2.
3. Execute Phases 2â€“5 and attach screenshots, screen recordings, Logcat captures, and Firestore timestamps before issuing a `PASS` or `FAIL` release determination.
