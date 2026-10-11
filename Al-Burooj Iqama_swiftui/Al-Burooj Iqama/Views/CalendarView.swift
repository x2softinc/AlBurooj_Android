import SwiftUI

/// Soft gold used for the Hijri numerals and the Hijri month caption,
/// so they read as a secondary accent against the maroon background.
fileprivate let hijriGold = Color(hex: 0xEAD0A2)

/// A general-purpose monthly calendar.
///
/// Shows the Gregorian month in a grid where every cell also carries its
/// matching Umm al-Qura Hijri day, mirroring the dual-date header used on the
/// Dashboard. The current day is highlighted in a white pill. Swipe or tap the
/// chevrons to move between months.
struct CalendarView: View {
    /// First day (midnight) of the month currently displayed.
    @State private var displayedMonth: Date = CalendarView.startOfCurrentMonth()

    private let gridItem = GridItem(.flexible(), spacing: 4)

    private var calendar: Calendar { Calendar.current }

    private var hijriCalendar: Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private var isShowingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    /// The first cell of the grid: the Sunday/Saturday (per locale) that
    /// precedes or equals the first day of the displayed month.
    private var gridStart: Date {
        let firstWeekday = calendar.firstWeekday
        let weekday = calendar.component(.weekday, from: displayedMonth)
        let offset = (weekday - firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: displayedMonth) ?? displayedMonth
    }

    /// Dates for every cell of the month grid (always whole weeks).
    private var dayDates: [Date] {
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        let firstWeekday = calendar.firstWeekday
        let weekday = calendar.component(.weekday, from: displayedMonth)
        let leading = (weekday - firstWeekday + 7) % 7
        let weeks = (leading + daysInMonth + 6) / 7
        return (0..<(weeks * 7)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                weekdayRow

                LazyVGrid(columns: Array(repeating: gridItem, count: 7), spacing: 4) {
                    ForEach(dayDates, id: \.self) { date in
                        DayCellView(
                            gregorianDay: calendar.component(.day, from: date),
                            hijriDay: hijriCalendar.component(.day, from: date),
                            isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                            isToday: calendar.isDateInToday(date)
                        )
                        .frame(height: 48)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)

                footer
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.gray)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .animation(.easeInOut(duration: 0.18), value: displayedMonth)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 12) {
            monthButton(systemImage: "chevron.left", offset: -1)

            Spacer(minLength: 4)

            VStack(spacing: 2) {
                Text(monthYearFormatter.string(from: displayedMonth))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(hijriCaption)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(hijriGold)
            }

            Spacer(minLength: 4)

            monthButton(systemImage: "chevron.right", offset: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private func monthButton(systemImage: String, offset: Int) -> some View {
        Button {
            if let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) {
                displayedMonth = calendar.dateInterval(of: .month, for: newMonth)?.start ?? newMonth
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .accessibilityLabel(offset < 0 ? "Previous month" : "Next month")
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { column in
                Text(weekdayLabel(column))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.12))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            // Legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white)
                    .frame(width: 10, height: 10)
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            if !isShowingCurrentMonth {
                Button("Today") {
                    withAnimation {
                        displayedMonth = Self.startOfCurrentMonth()
                    }
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(maroonColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.white, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    /// Short weekday label for a grid column, taken from the actual weekday of
    /// that column so it follows the device's first-weekday setting.
    private func weekdayLabel(_ column: Int) -> String {
        guard let date = calendar.date(byAdding: .day, value: column, to: gridStart) else {
            return ""
        }
        return weekdayFormatter.string(from: date)
    }

    /// Hijri month + year caption for the first day of the displayed month.
    private var hijriCaption: String {
        let text = hijriMonthFormatter.string(from: displayedMonth)
        return text.isEmpty ? "" : "\(text) AH"
    }

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var hijriMonthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = hijriCalendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEEE"
        return formatter
    }

    private static func startOfCurrentMonth() -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .month, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
    }
}

/// One cell of the month grid: a Gregorian day number with its Hijri day below.
private struct DayCellView: View {
    let gregorianDay: Int
    let hijriDay: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text("\(gregorianDay)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(isToday ? maroonColor : .white)

            Text("\(hijriDay)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(isToday ? maroonColor.opacity(0.85) : hijriGold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
            }
        }
        .opacity(isInDisplayedMonth ? 1 : 0.38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isToday
                ? "Today, Gregorian \(gregorianDay), Hijri \(hijriDay)"
                : "Gregorian \(gregorianDay), Hijri \(hijriDay)"
        )
    }
}

#Preview {
    NavigationStack {
        CalendarView()
            .navigationTitle("Calendar")
    }
}
