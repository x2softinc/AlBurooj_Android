package com.alburooj.app.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.MasjidInfo
import com.alburooj.app.data.network.UserFriendlyError
import com.alburooj.app.services.MasjidService
import com.alburooj.app.ui.components.UserFriendlyAlert
import com.alburooj.app.ui.theme.MaroonColor
import com.alburooj.app.ui.theme.ThemeColor
import com.alburooj.app.viewmodel.CurrentPrayerInfo
import com.alburooj.app.managers.LocationManager
import com.alburooj.app.viewmodel.TimesViewModel
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.ZoneId
import java.time.chrono.HijrahChronology
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.Date
import java.util.Locale

private const val MAX_DAY_OFFSET = 15 // 0 is today; 15 is fifteen days from today

/** Exposes the masjid/city strings so the host top bar can show them (DashboardView's nav title/toolbar). */
class DashboardHeader(val masjidName: String, val city: String)

@Composable
fun DashboardScreen(
    timesVM: TimesViewModel = viewModel(),
    locationManager: LocationManager? = null,
    onHeader: (DashboardHeader) -> Unit = {}
) {
    var masjidInfo by remember { mutableStateOf<MasjidInfo?>(null) }
    var currentError by remember { mutableStateOf<UserFriendlyError?>(null) }
    val pagerState = rememberPagerState(pageCount = { MAX_DAY_OFFSET + 1 })

    suspend fun loadMasjidInfo() {
        try {
            masjidInfo = MasjidService().fetchMasjidInfo()
        } catch (e: UserFriendlyError) {
            currentError = e
        } catch (e: Exception) {
            currentError = UserFriendlyError.dataLoading("Masjid Information") { loadMasjidInfo() }
        }
    }

    LaunchedEffect(Unit) { loadMasjidInfo() }
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { timesVM.loadSuspending(it) }
    }
    // Recalculate adhan times once a location fix arrives (or changes).
    if (locationManager != null) {
        val lat by locationManager.latitude.collectAsState()
        val lon by locationManager.longitude.collectAsState()
        LaunchedEffect(lat, lon) {
            if (lat != 0.0 || lon != 0.0) timesVM.loadSuspending(pagerState.currentPage)
        }
    }
    LaunchedEffect(masjidInfo) {
        val city = AppPrefs.getString(AppConstants.CITY).ifEmpty { masjidInfo?.city.orEmpty() }
        onHeader(DashboardHeader(masjidInfo?.masjidName.orEmpty(), city))
    }

    HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { offset ->
        DayPrayerPage(dayOffset = offset, timesVM = timesVM)
    }

    UserFriendlyAlert(currentError) { currentError = null }
}

private fun dateFor(offset: Int): Date = Calendar.getInstance().apply {
    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    add(Calendar.DAY_OF_YEAR, offset)
}.time

@Composable
private fun DayPrayerPage(dayOffset: Int, timesVM: TimesViewModel) {
    val adhan by timesVM.adhanTimes.collectAsState()
    val iqama by timesVM.iqamaTimes.collectAsState()
    val settings by timesVM.settings.collectAsState()
    val isLoading by timesVM.isLoading.collectAsState()
    val hasLoaded by timesVM.hasLoaded.collectAsState()
    val displayedOffset by timesVM.displayedDayOffset.collectAsState()
    val jurisdiction = AppPrefs.getInt(AppConstants.JURISDICTION)
    val pageDate = remember(dayOffset) { dateFor(dayOffset) }

    Column(
        modifier = Modifier.fillMaxSize().padding(2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        DateHeader(pageDate)

        if (isLoading || !hasLoaded || displayedOffset != dayOffset) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(color = ThemeColor)
                    Text("Loading prayer times…", Modifier.padding(top = 8.dp))
                }
            }
            return@Column
        }

        // Tick once a second so the current-prayer highlight and countdowns stay live (today only).
        var tick by remember { mutableStateOf(Date()) }
        LaunchedEffect(Unit) { while (true) { delay(1000); tick = Date() } }
        val current: CurrentPrayerInfo? = if (dayOffset == 0) remember(tick, adhan, iqama) { timesVM.currentPrayerInfo() } else null

        val ishaEnd = run {
            val isha = adhan.isha
            val midnight = adhan.midnight
            if (isha == null || midnight == null) null
            else if (midnight.before(isha)) Calendar.getInstance().apply { time = midnight; add(Calendar.DAY_OF_YEAR, 1) }.time
            else midnight
        }

        Column(
            Modifier.fillMaxSize().background(MaroonColor).verticalScroll(rememberScrollState()).padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            fun isCurrent(name: String) = current?.name?.let {
                when (name) {
                    "Dhuhar" -> it == "Dhuhar" || it == "Dhuhr"
                    "Asar" -> it == "Asar" || it == "Asr"
                    else -> it == name
                }
            } ?: false

            PrayerCard("Fajr", adhan.fajr, iqama?.fajr, isCurrent("Fajr"), adhan.sunrise, tick, timesVM)
            PrayerCard("Sunrise", adhan.sunrise, null, isCurrent("Sunrise"), null, tick, timesVM)
            PrayerCard("Dhuhar", adhan.dhuhar, iqama?.dhuhar, isCurrent("Dhuhar"), adhan.asar, tick, timesVM)
            PrayerCard(
                "Asar", if (jurisdiction != 0) adhan.asarHanafi else adhan.asar, iqama?.asar,
                isCurrent("Asar"), adhan.maghrib, tick, timesVM
            )
            PrayerCard("Maghrib", adhan.maghrib, iqama?.maghrib, isCurrent("Maghrib"), adhan.isha, tick, timesVM)
            PrayerCard("Isha", adhan.isha, iqama?.isha, isCurrent("Isha"), ishaEnd, tick, timesVM)

            JummaSection(settings?.jumma.orEmpty(), settings?.jumma2.orEmpty())
        }
    }
}

@Composable
private fun DateHeader(date: Date) {
    val gregorian = remember(date) { SimpleDateFormat("EEEE, MMMM d, yyyy", Locale.US).format(date) }
    val hijri = remember(date) {
        val local = date.toInstant().atZone(ZoneId.systemDefault()).toLocalDate()
        DateTimeFormatter.ofPattern("d MMMM yyyy", Locale.US).withChronology(HijrahChronology.INSTANCE)
            .format(LocalDate.from(local))
    }
    Column(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(gregorian, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(hijri, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = ThemeColor)
    }
}

private fun formatTime(date: Date?, pattern: String = "h:mm a") =
    date?.let { SimpleDateFormat(pattern, Locale.US).format(it) } ?: "--:--"

@Composable
private fun PrayerCard(
    title: String,
    adhanTime: Date?,
    iqamaTime: Date?,
    isCurrent: Boolean,
    boundaryTime: Date?,
    now: Date,
    timesVM: TimesViewModel
) {
    val textColor = if (isCurrent) Color.White else MaroonColor
    val shape = RoundedCornerShape(20.dp)
    val scale by animateFloatAsState(if (isCurrent) 1.012f else 1f, label = "scale")

    val background = if (isCurrent)
        Brush.linearGradient(listOf(Color(0xFFE6B8B8), Color(0xFF8D6E63)), Offset.Zero, Offset.Infinite)
    else Brush.linearGradient(listOf(Color.White, Color.White))

    Card(
        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp).graphicsLayer(scaleX = scale, scaleY = scale),
        shape = shape,
        elevation = CardDefaults.cardElevation(if (isCurrent) 10.dp else 3.dp),
        border = BorderStroke(if (isCurrent) 1.8.dp else 1.dp, if (isCurrent) Color.White else Color.White.copy(alpha = 0.6f))
    ) {
        Column(Modifier.background(background).padding(horizontal = 14.dp, vertical = 14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(30.dp).clip(CircleShape).background(Color.Black.copy(alpha = if (isCurrent) 0.12f else 0.04f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        if (isCurrent) Icons.Filled.Notifications else Icons.Filled.Schedule,
                        contentDescription = null,
                        tint = if (isCurrent) ThemeColor else Color.Gray,
                        modifier = Modifier.size(16.dp)
                    )
                }
                Column(Modifier.padding(start = 12.dp).weight(1f)) {
                    Text(title, fontWeight = FontWeight.Bold, fontSize = 17.sp, color = textColor)
                    Text(formatTime(adhanTime), fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = textColor)
                }
                if (iqamaTime != null) {
                    Column(horizontalAlignment = Alignment.End) {
                        Text(formatTime(iqamaTime), fontWeight = FontWeight.Bold, fontSize = 28.sp, color = textColor)
                        if (isCurrent && adhanTime != null) {
                            val c = timesVM.countdownInfo(now, adhanTime, iqamaTime, null)
                            Text(
                                c.countdown.ifEmpty { "--:--" },
                                fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold,
                                color = countdownColor(c.label)
                            )
                        }
                    }
                }
            }
            if (isCurrent && adhanTime != null && iqamaTime != null) {
                Spacer(Modifier.height(12.dp))
                ProgressBar(progressFor(now, adhanTime, iqamaTime, boundaryTime))
            }
        }
    }
}

private fun countdownColor(label: String): Color = when {
    label.contains("Since", true) -> Color.Red
    label.contains("Iqama", true) -> Color(0xFF2E7D32)
    label.contains("Adhan", true) -> Color(0xFFEF6C00)
    else -> Color.Gray
}

private class ProgressMetrics(val fraction: Float, val colors: List<Color>)

private val GreenColors = listOf(Color(0xFF2E7D32).copy(alpha = 0.45f), Color(0xFF2E7D32))

private fun progressFor(now: Date, adhan: Date, iqama: Date, boundary: Date?): ProgressMetrics {
    val interval = maxOf(iqama.time - adhan.time, 1000L).toDouble()
    if (now.before(adhan)) return ProgressMetrics(0f, GreenColors)
    if (now.before(iqama)) {
        return ProgressMetrics(((now.time - adhan.time) / interval).coerceIn(0.0, 1.0).toFloat(), GreenColors)
    }
    // After Iqama: yellow→red countdown to next prayer
    val nextAdhan = if (boundary != null && boundary.after(iqama)) boundary.time else (iqama.time + interval.toLong())
    val total = maxOf(nextAdhan - iqama.time, 1000L).toDouble()
    val remaining = maxOf(nextAdhan - now.time, 0L).toDouble()
    return ProgressMetrics((remaining / total).coerceIn(0.0, 1.0).toFloat(), listOf(Color.Yellow, Color.Red))
}

@Composable
private fun ProgressBar(m: ProgressMetrics) {
    val fraction by animateFloatAsState(m.fraction, label = "progress")
    Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.25f))) {
        Box(Modifier.fillMaxWidth(fraction).height(6.dp).clip(CircleShape).background(Brush.horizontalGradient(m.colors)))
    }
}

private fun displayJumma(raw: String): String {
    val trimmed = raw.trim()
    if (trimmed.isEmpty()) return "—"
    val parsed = runCatching { SimpleDateFormat("HH:mm", Locale.US).parse(trimmed) }.getOrNull() ?: return trimmed
    return SimpleDateFormat("hh:mm a", Locale.US).format(parsed)
}

@Composable
private fun JummaSection(raw1: String, raw2: String) {
    val has1 = raw1.isNotBlank()
    val has2 = raw2.isNotBlank()
    if (!has1 && !has2) return
    Card(
        Modifier.fillMaxWidth().padding(top = 6.dp),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.9f)),
        elevation = CardDefaults.cardElevation(3.dp)
    ) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (has1) JummaRow("Jumma", raw1, showIcon = true)
            if (has2) JummaRow("Jumma 2", raw2, showIcon = false)
        }
    }
}

@Composable
private fun JummaRow(title: String, time: String, showIcon: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            Icons.Filled.Groups, contentDescription = null, modifier = Modifier.size(18.dp),
            tint = if (showIcon) ThemeColor else Color.Transparent
        )
        Text(title, Modifier.padding(start = 8.dp).weight(1f), fontWeight = FontWeight.SemiBold)
        Text(displayJumma(time), fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = 17.sp)
    }
}
