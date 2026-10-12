package com.alburooj.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.alburooj.app.data.models.PrayerSetting
import com.alburooj.app.data.network.UserFriendlyError
import com.alburooj.app.services.PrayerSettingsService
import com.alburooj.app.ui.components.UserFriendlyAlert
import java.text.SimpleDateFormat
import java.util.Locale

/** Mapped from PrayerSettingsView.swift (not linked from Settings in the iOS app either). */
@Composable
fun PrayerSettingsScreen() {
    var settings by remember { mutableStateOf<PrayerSetting?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<UserFriendlyError?>(null) }

    suspend fun load() {
        isLoading = true; error = null
        try {
            settings = PrayerSettingsService().fetchPrayerSettings()
        } catch (e: UserFriendlyError) {
            error = e
        } catch (e: Exception) {
            error = UserFriendlyError.dataLoading("Prayer Settings") { load() }
        }
        isLoading = false
    }
    LaunchedEffect(Unit) { load() }

    Box(Modifier.fillMaxSize().padding(16.dp)) {
        if (isLoading) {
            Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(); Text("Loading prayer settings…", Modifier.padding(top = 8.dp))
            }
        } else {
            Card(Modifier.fillMaxWidth(), RoundedCornerShape(24.dp), elevation = CardDefaults.cardElevation(4.dp)) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Prayer Settings", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("Synced from server", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    HorizontalDivider()
                    val s = settings
                    SettingRow("Calculation Method", s?.calcMethod ?: "MWL")
                    SettingRow("Maintenance Method", (s?.maintMethod ?: 0).toString())
                    SettingRow("Jumma Time", displayTime(s?.jumma.orEmpty()))
                    SettingRow("Jumma 2 Time", displayTime(s?.jumma2.orEmpty()))
                    SettingRow("Asr Method", (s?.asrMethod ?: 0).toString())
                    SettingRow("Hijri Adjustment", (s?.hijriAdjustment ?: 0).toString())
                    SettingRow("Round Minutes", (s?.roundMinutes ?: 0).toString())
                    HorizontalDivider()
                    Text("Maghrib Delays (minutes)", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    SettingRow("Maghrib Delay (min)", (s?.maghribDelay ?: 3).toString())
                }
            }
        }
    }
    UserFriendlyAlert(error) { error = null }
}

@Composable
private fun SettingRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth()) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}

private fun displayTime(raw: String): String {
    if (raw.isEmpty()) return "—"
    val parsed = runCatching { SimpleDateFormat("HH:mm", Locale.US).parse(raw) }.getOrNull() ?: return raw
    return SimpleDateFormat("hh:mm a", Locale.US).format(parsed)
}
