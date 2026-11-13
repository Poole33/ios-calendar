import SwiftUI

struct CalendarPalette {
    let appearance: Appearance
    let scheme: ColorScheme

    var paper: Color {
        switch appearance.paper {
        case .white: color(0xffffff, 0x1d2620)
        case .mist: color(0xf5f8f6, 0x1e2823)
        case .ivory: color(0xfdfaf2, 0x29251e)
        }
    }

    var panel: Color {
        switch appearance.paper {
        case .white: color(0xf3f7f3, 0x222e25)
        case .mist: color(0xeaf2ed, 0x26342b)
        case .ivory: color(0xf4f0e5, 0x302b22)
        }
    }

    var accent: Color {
        switch appearance.accent {
        case .moss: color(0x336447, 0xa4cba8)
        case .pine: color(0x1e5c51, 0x8bcec1)
        case .slate: color(0x3d5977, 0xa7c7e6)
        }
    }

    var ink: Color { color(0x202a22, 0xe9efe7) }
    var secondary: Color { color(0x536459, 0xa8b8ac) }
    var divider: Color { color(0xdce7dd, 0x3b4b3f) }
    var onAccent: Color { color(0xffffff, 0x17261b) }
    var holiday: Color { color(0x97483e, 0xf1a79a) }
    var holidayFill: Color { color(0xf9e9e6, 0x4a302b) }
    var work: Color { color(0x625235, 0xe1cda3) }
    var workFill: Color { color(0xf0eadc, 0x3e3829) }
    var solarTerm: Color { color(0x3d6a54, 0x8ac4a7) }

    private func color(_ light: UInt32, _ dark: UInt32) -> Color {
        let value = scheme == .dark ? dark : light
        return Color(
            red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255
        )
    }
}

extension ScheduleColor {
    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

struct MonthHeader<Previous: View, Title: View, Next: View, Trailing: View>: View {
    @ViewBuilder var previous: () -> Previous
    @ViewBuilder var title: () -> Title
    @ViewBuilder var next: () -> Next
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                previous()
                title()
                next()
            }
            Spacer(minLength: 0)
            trailing()
        }
    }
}

struct MonthArrow: View {
    let previous: Bool
    let palette: CalendarPalette
    let compact: Bool

    var body: some View {
        Image(systemName: previous ? "chevron.left" : "chevron.right")
            .font(.system(size: compact ? 11 : 13, weight: .semibold))
            .foregroundStyle(palette.accent)
            .frame(width: compact ? 30 : 36, height: compact ? 28 : 34)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .accessibilityLabel(previous ? "上个月" : "下个月")
    }
}

struct MonthTitle: View {
    let date: CalendarDay
    let palette: CalendarPalette
    let compact: Bool

    var body: some View {
        Text(date.monthTitle)
            .font(.system(size: compact ? 19 : 25, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
    }
}

struct MonthGrid<Cell: View>: View {
    let dates: [CalendarDay]
    let palette: CalendarPalette
    let rowHeight: CGFloat
    @ViewBuilder var cell: (CalendarDay) -> Cell

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(index < 5 ? palette.secondary : palette.accent)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 16)
            .accessibilityHidden(true)
            ForEach(0..<6) { row in
                HStack(spacing: 0) {
                    ForEach(dates[(row * 7)..<((row + 1) * 7)]) { date in
                        cell(date)
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                    }
                }
            }
        }
    }
}

struct CalendarCell: View {
    let date: CalendarDay
    let selected: CalendarDay
    let today: CalendarDay
    let dots: [ScheduleColor]
    let palette: CalendarPalette
    let compact: Bool

    private var isSelected: Bool { date == selected }
    private var isInMonth: Bool { date.month == selected.month && date.year == selected.year }

    var body: some View {
        let info = DayInformation(date)
        VStack(spacing: 0) {
            Text(date.day, format: .number)
                .font(.system(size: compact ? 14 : 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(dateColor)
            Text(info.caption)
                .font(.system(size: compact ? 9 : 11))
                .foregroundStyle(captionColor(info))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(3)), id: \.self) { color in
                    Circle().fill(color.color).frame(width: 4, height: 4)
                        .overlay {
                            if isSelected { Circle().strokeBorder(palette.onAccent, lineWidth: 0.5) }
                        }
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if isSelected { RoundedRectangle(cornerRadius: 8).fill(palette.accent) }
        }
        .overlay {
            if date == today && !isSelected {
                RoundedRectangle(cornerRadius: 8).strokeBorder(palette.accent, lineWidth: 1)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let holiday = info.holiday {
                holidayBadge(holiday)
                    .padding(.top, 1)
                    .padding(.trailing, 1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(info))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var dateColor: Color {
        if isSelected { return palette.onAccent }
        if !isInMonth { return palette.secondary.opacity(0.68) }
        return date.isWeekend ? palette.holiday : palette.ink
    }

    private func captionColor(_ info: DayInformation) -> Color {
        if isSelected { return palette.onAccent }
        if !isInMonth { return palette.secondary.opacity(0.68) }
        if info.festival != nil { return palette.holiday }
        return info.solarTerm == nil ? palette.secondary : palette.solarTerm
    }

    private func holidayBadge(_ mark: MainlandHolidays.Mark) -> some View {
        let isRest = mark.badge == "休"
        return Text(mark.badge)
            .font(.system(size: compact ? 7 : 8, weight: .semibold))
            .foregroundStyle(isRest ? palette.holiday : palette.work)
            .padding(.horizontal, 1)
            .background(isRest ? palette.holidayFill : palette.workFill, in: RoundedRectangle(cornerRadius: 2))
            .accessibilityHidden(true)
    }

    private func accessibilityLabel(_ info: DayInformation) -> String {
        let dateParts = [date.accessibleDate, info.lunar.detail, date == today ? "今天" : nil]
        let tags = [info.festival, info.solarTerm, info.holiday?.detail, dots.isEmpty ? nil : "有日程"]
        return (dateParts + tags).compactMap { $0 }.joined(separator: "，")
    }
}
