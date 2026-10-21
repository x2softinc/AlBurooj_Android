package com.alburooj.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alburooj.app.ui.theme.MaroonColor
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.chrono.HijrahChronology
import java.time.chrono.HijrahDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.time.temporal.WeekFields
import java.util.Locale

/** Soft gold used for Hijri numerals/caption against the maroon background. */
private val HijriGold = Color(0xFFEAD0A2)
private val CalendarBackground = Color(0xFF808080)

/** Mapped from CalendarView.swift: monthly Gregorian grid with Umm al-Qura Hijri days. */
@Composable
fun CalendarScreen() {
    var displayedMonth by remember { mutableStateOf(YearMonth.now()) }
    val today = LocalDate.now()
    val firstDay = WeekFields.of(Locale.getDefault()).firstDayOfWeek

    val first = displayedMonth.atDay(1)
    val leading = (first.dayOfWeek.value - firstDay.value + 7) % 7
    val weeks = (leading + displayedMonth.lengthOfMonth() + 6) / 7
    val gridStart = first.minusDays(leading.toLong())
    val days = (0 until weeks * 7).map { gridStart.plusDays(it.toLong()) }

    val hijriCaption = remember(displayedMonth) {
        runCatching {
            DateTimeFormatter.ofPattern("MMMM yyyy", Locale.US).withChronology(HijrahChronology.INSTANCE)
                .format(HijrahDate.from(first)) + " AH"
        }.getOrDefault("")
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 12.dp, vertical = 10.dp)
    ) {
        Column(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(CalendarBackground)
                .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(24.dp))
        ) {
            // Header
            Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                MonthButton(Icons.Filled.ChevronLeft, "Previous month") { displayedMonth = displayedMonth.minusMonths(1) }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "${displayedMonth.month.getDisplayName(TextStyle.FULL, Locale.US)} ${displayedMonth.year}",
                        color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp
                    )
                    Text(hijriCaption, color = HijriGold, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                }
                MonthButton(Icons.Filled.ChevronRight, "Next month") { displayedMonth = displayedMonth.plusMonths(1) }
            }

            // Weekday row
            Row(Modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.12f)).padding(horizontal = 10.dp, vertical = 6.dp)) {
                for (col in 0 until 7) {
                    val dow = DayOfWeek.of(((firstDay.value - 1 + col) % 7) + 1)
                    Text(
                        dow.getDisplayName(TextStyle.NARROW, Locale.US),
                        Modifier.weight(1f), textAlign = TextAlign.Center,
                        color = Color.White.copy(alpha = 0.85f), fontWeight = FontWeight.SemiBold, fontSize = 12.sp
                    )
                }
            }

            // Grid
            Column(Modifier.padding(horizontal = 10.dp, vertical = 2.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                days.chunked(7).forEach { week ->
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        week.forEach { date ->
                            DayCell(
                                date = date,
                                inMonth = YearMonth.from(date) == displayedMonth,
                                isToday = date == today,
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }

            // Footer
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(10.dp).clip(RoundedCornerShape(4.dp)).background(Color.White))
                Text("Today", Modifier.padding(start = 6.dp).weight(1f), color = Color.White.copy(alpha = 0.9f), fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                if (displayedMonth != YearMonth.now()) {
                    Text(
                        "Today",
                        Modifier.clip(CircleShape).background(Color.White).clickable { displayedMonth = YearMonth.now() }
                            .padding(horizontal = 12.dp, vertical = 5.dp),
                        color = MaroonColor, fontWeight = FontWeight.Bold, fontSize = 13.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun MonthButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit) {
    IconButton(onClick, Modifier.size(34.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.12f))) {
        Icon(icon, contentDescription = label, tint = Color.White)
    }
}

@Composable
private fun DayCell(date: LocalDate, inMonth: Boolean, isToday: Boolean, modifier: Modifier) {
    val hijriDay = remember(date) { runCatching { HijrahDate.from(date).get(java.time.temporal.ChronoField.DAY_OF_MONTH) }.getOrDefault(0) }
    Column(
        modifier.height(48.dp).alpha(if (inMonth) 1f else 0.38f)
            .clip(RoundedCornerShape(12.dp)).background(if (isToday) Color.White else Color.Transparent),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("${date.dayOfMonth}", fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = if (isToday) MaroonColor else Color.White)
        Text("$hijriDay", fontWeight = FontWeight.Medium, fontSize = 11.sp, color = if (isToday) MaroonColor.copy(alpha = 0.85f) else HijriGold)
    }
}
