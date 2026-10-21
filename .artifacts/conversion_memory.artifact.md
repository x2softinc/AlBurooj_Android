# Conversion Memory: AlBurooj Iqama (SwiftUI to Jetpack Compose)

## Project Overview
- **Source:** SwiftUI Project (`Al-Burooj Iqama_swiftui/Al-Burooj Iqama/`)
- **Target:** Android Jetpack Compose Project (`Al-Burooj Iqama_android`)
- **Base Package:** `com.alburooj.app`
- **Architecture:** MVVM + Service pattern. No DI; `AppPrefs` object replaces @AppStorage/UserDefaults (init in `AlBuroojApp`).

## Progress Tracking
### Completed (session 2 rewrote the mock-based session-1 services against real networking)
- [x] Gradle project (settings/build/app build.gradle.kts, manifest, theme). NOTE: no gradle wrapper and gradle not installed in CLI, so nothing has been compiled yet. Open in Android Studio to sync (it generates the wrapper) and fix compile errors.
- [x] `AppPrefs`, `AlBuroojApp`
- [x] Constants (`AppConstants`), `MasjidProApiPaths`, `VersionInfo`
- [x] Models: AdhanTime, IqamaTime (not @Serializable: Date, never persisted), PrayerSetting, MasjidInfo, AnnualTime, Payloads
- [x] Network: `ApiClient` (OkHttp), `UserFriendlyError` (+`RecoveryAction`, `HttpException`), `authorizedGet` (401 refresh+retry)
- [x] Helpers: `AppHelpers.kt` (getDeviceCode, getBaseUrl, todayKey), `PrayTimesCalculator`
- [x] Services: AuthService, MasjidService, AdhanTimesService, IqamaTimesService, PrayerSettingsService, VersionService (API key via BuildConfig.VERSION_API_KEY / gradle prop)
- [x] `LocationManager` (fused location + rotation-vector heading; persists LATT/LONG/CITY)
- [x] `TimesViewModel` (viewmodel/)

### Completed (session 3): everything else; `./gradlew :app:assembleDebug` BUILDS
- [x] Models: Announcement/TimeDelay/FixedTime (SmallModels.kt), AdhanSoundOption (mp3s copied to res/raw, lowercase)
- [x] `notifications/` NotificationScheduler (AlarmManager one-shot + re-arm in NotificationReceiver; BootReceiver; per-sound channels)
- [x] UI: theme, MainScreen (tabs+drawer+NavHost), Dashboard, Calendar, Qibla (compass.png in drawable-nodpi), Masjid, Settings, PrayerSettings (unrouted, as on iOS), AdhanSoundSelection, EULA, LegalDocument (WebView), AppVersionGate, UserFriendlyAlert
- [x] Fixed PrayTimesCalculator compile errors; added Gradle wrapper 8.11.1

### Build notes
- Build with JBR 21 (`JAVA_HOME=~/Library/Java/JavaVirtualMachines/jbr-21.0.11/Contents/Home`); JDK 25/27 break Gradle 8.11. AGP 8.7.3, Kotlin 2.0.20, compileSdk 35.
- VERSION_API_KEY gradle property feeds BuildConfig (empty by default, so the version check just fails open).

### Open items / not verified at runtime
- Never run on a device/emulator: network flow, alarms, compass, notification sounds untested.
- EULA text still says Apple devices and has [Jurisdiction]/[Date] placeholders (verbatim from iOS) - needs legal review.
- APP_URL points to a guessed Play Store URL (com.alburooj.app).
- Masjid inline map replaced by a Directions button (no Maps SDK key).
- No launcher icon / adaptive icon yet; no unit tests ported.

## Technical Notes
- Time: `java.util.Date` / Calendar. Doubles in AppPrefs stored as raw long bits.
- JSON: kotlinx.serialization, `ignoreUnknownKeys`.
- Navigation: Compose Navigation.
