package com.alburooj.app.ui.screens

import android.Manifest
import android.app.AlarmManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.AdhanSoundOption
import com.alburooj.app.data.models.AdhanSoundPreference
import com.alburooj.app.helper.getDeviceCode
import com.alburooj.app.notifications.NotificationScheduler
import com.alburooj.app.services.AuthService
import com.alburooj.app.ui.theme.ThemeColor
import kotlinx.coroutines.launch

private val CalculationMethods = mapOf(
    "ISNA" to "Islamic Society of North America",
    "MWL" to "Muslim World League",
    "EGAS" to "Egiptian General Authority of Survey",
    "UQUM" to "Ummul Qura - Makkah",
    "UISK" to "United Islamic Science, Karachi",
    "MUIS" to "Majilis Ugama Islam Singapura",
    "TEH" to "Institute of Geophysics, University of Tehran",
    "JAF" to "Jafari"
)

/** Mapped from SettingsView.swift. */
@Composable
fun SettingsScreen(onAdhanSound: () -> Unit, onTerms: () -> Unit, onPrivacy: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var calcMethod by remember { mutableStateOf(AppPrefs.getString(AppConstants.CALC_METH, "ISNA")) }
    var jurisdiction by remember { mutableStateOf(AppPrefs.getInt(AppConstants.JURISDICTION)) }
    var notificationsEnabled by remember { mutableStateOf(AppPrefs.getBoolean(AppConstants.NOTIFICATION_ENABLED)) }
    var notifyAdhan by remember { mutableStateOf(AppPrefs.getBoolean(AppConstants.NOTIFY_ADHAN)) }
    var notifyIqama by remember { mutableStateOf(AppPrefs.getBoolean(AppConstants.NOTIFY_IQAMA)) }
    var isReconnecting by remember { mutableStateOf(false) }
    var connectedTick by remember { mutableStateOf(0) }
    var alert by remember { mutableStateOf<Pair<String, String>?>(null) }
    var showDenied by remember { mutableStateOf(false) }

    var resumeTick by remember { mutableStateOf(0) }
    LifecycleResumeEffect(Unit) { resumeTick++; onPauseOrDispose { } }
    val needsExactAlarm = resumeTick >= 0 && Build.VERSION.SDK_INT >= 31 &&
        !(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()

    val auth = remember { AuthService() }
    val isConnected = connectedTick >= 0 && AppPrefs.getString(AppConstants.AUTH_TOKEN).isNotEmpty() && !auth.isAuthTokenExpired()

    fun sync() = scope.launch { NotificationScheduler(context).syncNotifications() }
    LaunchedEffect(Unit) { sync() }

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted) {
            notificationsEnabled = false
            AppPrefs.putBoolean(AppConstants.NOTIFICATION_ENABLED, false)
            showDenied = true
        }
        sync()
    }

    val city = AppPrefs.getString(AppConstants.CITY)
    val lat = AppPrefs.getDouble(AppConstants.LATT)
    val lon = AppPrefs.getDouble(AppConstants.LONG)
    val location = when {
        city.isNotEmpty() -> city
        lat != 0.0 || lon != 0.0 -> String.format("%.4f, %.4f", lat, lon)
        else -> "Not Set"
    }
    val pkg = remember { context.packageManager.getPackageInfo(context.packageName, 0) }
    val appName = "Al-Burooj Iqama"
    val appVersion = pkg.versionName ?: "1.0"
    val build = if (Build.VERSION.SDK_INT >= 28) pkg.longVersionCode.toString() else @Suppress("DEPRECATION") pkg.versionCode.toString()
    val soundName = AdhanSoundOption.fromRaw(AppPrefs.getString(AdhanSoundPreference.STORAGE_KEY, AdhanSoundOption.SystemDefault.raw)).displayName

    LazyColumn {
        item { Header("Version Info") }
        item { ValueRow("App", appName) }
        item { ValueRow("Version / Build", "$appVersion / $build") }
        item { ActionRow("Check for Updates") { openStore(context) } }

        item { Header("Adhan Settings") }
        item {
            var expanded by remember { mutableStateOf(false) }
            Row(Modifier.fillMaxWidth().clickable { expanded = true }.padding(16.dp)) {
                Text("Calculation Method", Modifier.weight(1f))
                Text(CalculationMethods[calcMethod] ?: calcMethod, color = MaterialTheme.colorScheme.onSurfaceVariant)
                DropdownMenu(expanded, { expanded = false }) {
                    CalculationMethods.entries.sortedBy { it.value }.forEach { (key, name) ->
                        DropdownMenuItem(text = { Text(name) }, onClick = {
                            calcMethod = key; AppPrefs.putString(AppConstants.CALC_METH, key); expanded = false
                        })
                    }
                }
            }
        }
        item {
            var expanded by remember { mutableStateOf(false) }
            Row(Modifier.fillMaxWidth().clickable { expanded = true }.padding(16.dp)) {
                Text("Asr Jurisdiction", Modifier.weight(1f))
                Text(if (jurisdiction == 0) "Standard" else "Hanafi", color = MaterialTheme.colorScheme.onSurfaceVariant)
                DropdownMenu(expanded, { expanded = false }) {
                    listOf("Standard", "Hanafi").forEachIndexed { i, label ->
                        DropdownMenuItem(text = { Text(label) }, onClick = {
                            jurisdiction = i; AppPrefs.putInt(AppConstants.JURISDICTION, i); expanded = false; sync()
                        })
                    }
                }
            }
        }
        item { ValueRow("Location", location) }
        item { Note("These adhan calculation preferences are stored locally on this device.") }

        item { Header("Notifications") }
        item {
            ToggleRow("Enable Notifications", notificationsEnabled, true) { on ->
                notificationsEnabled = on
                AppPrefs.putBoolean(AppConstants.NOTIFICATION_ENABLED, on)
                if (on && Build.VERSION.SDK_INT >= 33) permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS) else sync()
            }
        }
        item { ToggleRow("Notify Adhan", notifyAdhan, notificationsEnabled) { notifyAdhan = it; AppPrefs.putBoolean(AppConstants.NOTIFY_ADHAN, it); sync() } }
        item { ToggleRow("Notify Iqama", notifyIqama, notificationsEnabled) { notifyIqama = it; AppPrefs.putBoolean(AppConstants.NOTIFY_IQAMA, it); sync() } }
        item {
            val enabled = notificationsEnabled && notifyAdhan
            Row(Modifier.fillMaxWidth().clickable(enabled = enabled, onClick = onAdhanSound).padding(16.dp)) {
                Text("Adhan Sound", Modifier.weight(1f), color = if (enabled) Color.Unspecified else MaterialTheme.colorScheme.outline)
                Text(soundName, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (notificationsEnabled && needsExactAlarm) {
            item {
                ActionRow("Allow Exact Alarms") {
                    context.startActivity(
                        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                }
            }
            item { Note("Without this permission, prayer reminders may arrive several minutes late.") }
        }
        item { Note("The selected sound is used only for Adhan notifications. Iqama notifications keep the default system sound.") }

        item { Header("App Access") }
        item {
            Row(Modifier.fillMaxWidth().padding(16.dp)) {
                Text("Connection", Modifier.weight(1f))
                Text(if (isConnected) "Connected" else "Reconnect Needed", color = if (isConnected) Color(0xFF2E7D32) else Color(0xFFEF6C00))
            }
        }
        if (!isConnected) {
            item {
                if (isReconnecting) {
                    Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.Center) { CircularProgressIndicator() }
                } else {
                    ActionRow("Reconnect Now") {
                        isReconnecting = true
                        scope.launch {
                            try { auth.getDeviceToken() } catch (e: Exception) { alert = "Unable to Reconnect" to (e.message ?: "Unknown error") }
                            isReconnecting = false; connectedTick++
                        }
                    }
                }
            }
        }
        item { Note("Use this device code to connect the app to your Masjid Pro account.") }

        item { Header("Support") }
        item {
            ActionRow("Copy Support Information") {
                val info = "$appName\nVersion: $appVersion ($build)\nDevice Code: ${getDeviceCode()}"
                (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Support", info))
            }
        }
        item { ActionRow("Rate on Play Store") { openStore(context) } }

        item { Header("Legal") }
        item { ActionRow(LegalDocument.TermsOfUse.title, onTerms) }
        item { ActionRow(LegalDocument.PrivacyPolicy.title, onPrivacy) }
        item { Note("The Privacy Policy is hosted online and may be updated from time to time.") }
    }

    alert?.let { (title, message) ->
        AlertDialog({ alert = null }, confirmButton = { TextButton({ alert = null }) { Text("OK") } }, title = { Text(title) }, text = { Text(message) })
    }
    if (showDenied) {
        AlertDialog(
            { showDenied = false },
            title = { Text("Notifications Not Authorized") },
            text = { Text("Allow notifications in System Settings to receive prayer reminders.") },
            confirmButton = {
                TextButton({
                    showDenied = false
                    context.startActivity(
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                }) { Text("Open Settings") }
            },
            dismissButton = { TextButton({ showDenied = false }) { Text("Cancel") } }
        )
    }
}

private fun openStore(context: Context) {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(AppConstants.APP_URL)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

@Composable
private fun Header(text: String) {
    Text(text, Modifier.padding(start = 16.dp, top = 20.dp, bottom = 4.dp), style = MaterialTheme.typography.labelLarge, color = ThemeColor, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun Note(text: String) {
    Text(text, Modifier.padding(horizontal = 16.dp, vertical = 6.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    HorizontalDivider()
}

@Composable
private fun ValueRow(title: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(16.dp)) {
        Text(title, Modifier.weight(1f))
        Text(value, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun ActionRow(title: String, onClick: () -> Unit) {
    Text(title, Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp), color = ThemeColor)
}

@Composable
private fun ToggleRow(title: String, checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f), color = if (enabled) Color.Unspecified else MaterialTheme.colorScheme.outline)
        Switch(checked, onChange, enabled = enabled)
    }
}
