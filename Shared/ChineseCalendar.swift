import Foundation

struct LunarDate {
    let month: Int
    let day: Int
    let isLeapMonth: Bool
    let yearName: String

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = CalendarDay.chinaTimeZone
        return calendar
    }()

    private static let stems = Array("甲乙丙丁戊己庚辛壬癸")
    private static let branches = Array("子丑寅卯辰巳午未申酉戌亥")
    private static let months = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
    private static let days = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十",
    ]

    init(_ date: CalendarDay) {
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: date.start(in: CalendarDay.civilCalendar) + 43_200)
        month = parts.month!
        day = parts.day!
        isLeapMonth = parts.isLeapMonth == true
        let cycle = parts.year! - 1
        yearName = "\(Self.stems[cycle % 10])\(Self.branches[cycle % 12])年"
    }

    var monthName: String { (isLeapMonth ? "闰" : "") + Self.months[month - 1] }
    var dayName: String { Self.days[day - 1] }
    var header: String { "\(yearName) · \(monthName)" }
    var detail: String { "\(header)\(dayName)" }
}

struct DayInformation {
    let lunar: LunarDate
    let festival: String?
    let solarTerm: String?
    let holiday: MainlandHolidays.Mark?

    init(_ date: CalendarDay) {
        lunar = LunarDate(date)
        solarTerm = SolarTerms.name(on: date)
        festival = Self.festival(on: date, lunar: lunar, solarTerm: solarTerm)
        holiday = MainlandHolidays.mark(on: date)
    }

    var caption: String { festival ?? solarTerm ?? (lunar.day == 1 ? lunar.monthName : lunar.dayName) }

    private static func festival(on date: CalendarDay, lunar: LunarDate, solarTerm: String?) -> String? {
        switch (date.month, date.day) {
        case (1, 1): return "元旦"
        case (5, 1): return "劳动节"
        case (10, 1): return "国庆节"
        default: break
        }
        if solarTerm == "清明" { return "清明节" }
        if lunar.isLeapMonth { return nil }
        switch (lunar.month, lunar.day) {
        case (1, 1): return "春节"
        case (1, 15): return "元宵节"
        case (5, 5): return "端午节"
        case (7, 7): return "七夕"
        case (7, 15): return "中元节"
        case (8, 15): return "中秋节"
        case (9, 9): return "重阳节"
        case (12, 8): return "腊八节"
        case (12, 29), (12, 30):
            let next = LunarDate(date.addingDays(1))
            return next.month == 1 && next.day == 1 && !next.isLeapMonth ? "除夕" : nil
        default: return nil
        }
    }
}
