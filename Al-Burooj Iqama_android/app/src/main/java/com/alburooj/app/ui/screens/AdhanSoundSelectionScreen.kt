package com.alburooj.app.ui.screens

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.StopCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.AdhanSoundOption
import com.alburooj.app.data.models.AdhanSoundPreference
import com.alburooj.app.notifications.NotificationScheduler
import com.alburooj.app.ui.theme.ThemeColor

/** Mapped from AdhanSoundSelectionView.swift. */
@Composable
fun AdhanSoundSelectionScreen() {
    val context = LocalContext.current
    var selected by remember { mutableStateOf(AppPrefs.getString(AdhanSoundPreference.STORAGE_KEY, AdhanSoundOption.SystemDefault.raw)) }
    var previewing by remember { mutableStateOf<AdhanSoundOption?>(null) }
    var player by remember { mutableStateOf<MediaPlayer?>(null) }

    fun stop() {
        player?.runCatching { stop(); release() }
        player = null; previewing = null
    }

    fun play(option: AdhanSoundOption) {
        stop()
        val uri = option.uri(context) ?: return
        runCatching {
            player = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build())
                setDataSource(context, Uri.parse(uri))
                setOnCompletionListener { stop() }
                prepare(); start()
            }
            previewing = option
        }.onFailure { stop() }
    }

    DisposableEffect(Unit) { onDispose { stop() } }
    LaunchedEffect(selected) { NotificationScheduler(context).syncNotifications() }

    LazyColumn {
        items(AdhanSoundOption.entries) { option ->
            Row(
                Modifier.fillMaxWidth().clickable { selected = option.raw; AppPrefs.putString(AdhanSoundPreference.STORAGE_KEY, option.raw); stop() }
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(option.displayName, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
                if (selected == option.raw) Icon(Icons.Filled.CheckCircle, "Selected", tint = ThemeColor)
                if (option.resName != null) {
                    val isPlaying = previewing == option
                    IconButton({ if (isPlaying) stop() else play(option) }) {
                        Icon(
                            if (isPlaying) Icons.Filled.StopCircle else Icons.Filled.PlayCircle,
                            if (isPlaying) "Stop ${option.displayName}" else "Play ${option.displayName}",
                            tint = ThemeColor
                        )
                    }
                }
            }
        }
        item {
            Text(
                "The selected sound is used only for Adhan notifications. Iqama notifications keep the default system sound.",
                Modifier.padding(16.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
