package com.alburooj.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Pin
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alburooj.app.data.models.MasjidInfo
import com.alburooj.app.services.MasjidService

private val Accent = Color(0xFF0099CC)

/** Mapped from MasjidView.swift. The iOS inline map becomes a Directions button (no Maps SDK key needed). */
@Composable
fun MasjidScreen() {
    var info by remember { mutableStateOf<MasjidInfo?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        isLoading = true; error = null
        try { info = MasjidService().fetchMasjidInfo() } catch (e: Exception) { error = e.message }
        isLoading = false
    }

    Box(Modifier.fillMaxSize().padding(16.dp)) {
        when {
            isLoading -> Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(); Text("Loading Masjid info…", Modifier.padding(top = 8.dp))
            }
            error != null -> Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Filled.Warning, null, tint = Color(0xFFEF6C00), modifier = Modifier.size(40.dp))
                Text(error!!, textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            info != null -> MasjidCard(info!!, fillScreen = LocalConfiguration.current.let { it.screenWidthDp >= 600 && it.screenHeightDp >= 480 })
            else -> Text("No masjid information available.", Modifier.align(Alignment.Center))
        }
    }
}

@Composable
private fun MasjidCard(info: MasjidInfo, fillScreen: Boolean) {
    val context = LocalContext.current
    val k = rememberTabletScale()
    Card(
        if (fillScreen) Modifier.fillMaxSize() else Modifier.fillMaxWidth().verticalScroll(rememberScrollState()),
        shape = RoundedCornerShape(24.dp),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column(
            Modifier.then(if (fillScreen) Modifier.fillMaxSize().padding(32.dp) else Modifier.padding(20.dp)),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size((44 * k).dp).clip(CircleShape).background(Accent.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Business, null, tint = Accent, modifier = Modifier.size((24 * k).dp))
                }
                Text(info.masjidName ?: "Unknown Masjid", Modifier.padding(start = 12.dp), style = MaterialTheme.typography.titleLarge, fontSize = (22 * k).sp, fontWeight = FontWeight.SemiBold)
            }
            val rows = listOfNotNull(
                info.address?.takeIf { it.isNotEmpty() }?.let { Triple(Icons.Filled.Place, "Address", it) },
                info.address1?.takeIf { it.isNotEmpty() }?.let { Triple(Icons.Filled.LocationOn, "Address Line 2", it) },
                listOfNotNull(info.city, info.state).filter { it.isNotEmpty() }.joinToString(", ").takeIf { it.isNotEmpty() }
                    ?.let { Triple(Icons.Filled.LocationOn, "City/State", it) },
                info.postalCode?.takeIf { it.isNotEmpty() }?.let { Triple(Icons.Filled.Pin, "Postal Code", it) },
                info.country?.takeIf { it.isNotEmpty() }?.let { Triple(Icons.Filled.Language, "Country", it) },
                info.phone?.takeIf { it.isNotEmpty() }?.let { Triple(Icons.Filled.Phone, "Phone", it) },
                info.email?.takeIf { it.isNotEmpty() }?.let { Triple(Icons.Filled.Email, "Email", it) },
                info.url?.takeIf { it.isNotEmpty() }?.let { Triple(Icons.Filled.Link, "Website", it) }
            )
            if (fillScreen) {
                // Full-screen: details in two columns, directions pinned to the bottom.
                Column(Modifier.padding(start = 16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    rows.chunked(2).forEach { pair ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                            pair.forEach { (icon, label, value) -> Box(Modifier.weight(1f)) { InfoRow(icon, label, value) } }
                            if (pair.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
                Spacer(Modifier.weight(1f))
            } else {
                Column(Modifier.padding(start = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    rows.forEach { (icon, label, value) -> InfoRow(icon, label, value) }
                }
            }
            HorizontalDivider()
            if (info.latitude != 0.0 || info.longitude != 0.0) {
                Button(
                    onClick = {
                        val label = Uri.encode(info.masjidName ?: "Masjid")
                        val uri = Uri.parse("google.navigation:q=${info.latitude},${info.longitude}&mode=d")
                        val fallback = Uri.parse("geo:${info.latitude},${info.longitude}?q=${info.latitude},${info.longitude}($label)")
                        val intent = Intent(Intent.ACTION_VIEW, uri)
                        runCatching { context.startActivity(intent) }
                            .onFailure { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, fallback)) } }
                    },
                    modifier = Modifier.fillMaxWidth().height((48 * k).dp)
                ) {
                    Icon(Icons.Filled.DirectionsCar, null); Text("  Driving Directions", fontSize = (16 * k).sp)
                }
            }
        }
    }
}

@Composable
private fun InfoRow(icon: ImageVector, label: String, value: String) {
    val k = rememberTabletScale()
    Row(verticalAlignment = Alignment.Top) {
        Icon(icon, null, tint = Accent, modifier = Modifier.size((20 * k).dp).padding(top = 2.dp))
        Column(Modifier.padding(start = 12.dp)) {
            Text(label, style = MaterialTheme.typography.labelSmall, fontSize = (12 * k).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, style = MaterialTheme.typography.bodyMedium, fontSize = (16 * k).sp)
        }
    }
}
