import Foundation

/// A Gregorian date without a time zone. Calendar labels use China Standard Time;
/// event queries and "today" use the device's local time zone.
struct CalendarDay: Hashable, Comparable, Sendable, Identifiable {
    static let supportedYears = 1901...2100
    static let chinaTimeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
    static let civilCalendar = gregorian(in: chinaTimeZone)

    static func gregorian(in timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    let year: Int
    let month: Int
    let day: Int

    init?(_ year: Int, _ month: Int, _ day: Int) {
        guard (1900...2101).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        let calendar = Self.civilCalendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else { return nil }
        self.init(date, in: calendar)
        guard self.year == year, self.month == month, self.day == day else { return nil }
    }

    init?(_ key: String) {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = Self(year, month, day), date.id == key else { return nil }
        self = date
    }

    init(_ date: Date, in calendar: Calendar = Self.gregorian()) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year!
        month = parts.month!
        day = parts.day!
    }

    static var today: Self { Self(.now) }

    var id: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var isSupported: Bool { Self.supportedYears.contains(year) }
    var monthTitle: String { "\(year)年 \(month)月" }
    var monthStart: Self { Self(year, month, 1)! }
    var weekday: Int { Self.civilCalendar.component(.weekday, from: chinaNoon) }
    var isWeekend: Bool { weekday == 1 || weekday == 7 }
    var weekdayName: String { ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][weekday - 1] }
    var accessibleDate: String { "\(year)年\(month)月\(day)日，\(weekdayName)" }

    private var chinaNoon: Date { instant(in: Self.civilCalendar) }

    private func instant(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func start(in calendar: Calendar) -> Date {
        calendar.startOfDay(for: instant(in: calendar))
    }

    func addingDays(_ count: Int) -> Self {
        let calendar = Self.civilCalendar
        return Self(calendar.date(byAdding: .day, value: count, to: chinaNoon)!, in: calendar)
    }

    func addingMonths(_ count: Int) -> Self {
        let calendar = Self.civilCalendar
        return Self(calendar.date(byAdding: .month, value: count, to: chinaNoon)!, in: calendar)
    }

    func monthGrid() -> [Self] {
        let first = monthStart
        let monday = first.addingDays(-((first.weekday + 5) % 7))
        return (0..<42).map { monday.addingDays($0) }
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        let first = Self(year, month, 1)!
        return civilCalendar.range(of: .day, in: .month, for: first.chinaNoon)!.count
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
