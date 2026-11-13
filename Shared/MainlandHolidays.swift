import Foundation

enum MainlandHolidays {
    enum Mark: Codable, Equatable, Sendable {
        case rest(String)
        case work

        var badge: String {
            switch self {
            case .rest: "休"
            case .work: "班"
            }
        }

        var detail: String {
            switch self {
            case .rest(let holiday): "\(holiday)假期"
            case .work: "调休上班"
            }
        }
    }

    struct DownloadedSchedule: Codable {
        let days: [String: Mark]
        let checkedAt: Date
    }

    typealias DownloadedSchedules = [Int: DownloadedSchedule]

    private struct YearSchedule {
        let holidays: [(month: Int, days: ClosedRange<Int>, name: String)]
        let workDays: Set<Int>
    }

    // 国办发明电〔2025〕7号和〔2026〕10号。工作日使用 MMDD。
    private static let schedules = [
        2026: YearSchedule(
            holidays: [
                (1, 1...3, "元旦"), (2, 15...23, "春节"), (4, 4...6, "清明节"),
                (5, 1...5, "劳动节"), (6, 19...21, "端午节"), (9, 25...27, "中秋节"),
                (10, 1...7, "国庆节"),
            ],
            workDays: [104, 214, 228, 509, 920, 1010]
        ),
        2027: YearSchedule(
            holidays: [
                (1, 1...3, "元旦"), (2, 5...13, "春节"), (4, 3...5, "清明节"),
                (5, 1...5, "劳动节"), (6, 9...9, "端午节"), (9, 15...15, "中秋节"),
                (10, 1...7, "国庆节"),
            ],
            workDays: [131, 214, 508, 926, 1009]
        ),
    ]

    static func mark(on date: CalendarDay, using downloaded: DownloadedSchedules = [:]) -> Mark? {
        if date.month == 12, let mark = downloaded[date.year + 1]?.days[date.id] { return mark }
        if let schedule = downloaded[date.year] { return schedule.days[date.id] }
        guard let schedule = schedules[date.year] else { return nil }
        if schedule.workDays.contains(date.month * 100 + date.day) { return .work }
        let holiday = schedule.holidays.first { $0.month == date.month && $0.days.contains(date.day) }
        return holiday.map { .rest($0.name) }
    }
}
