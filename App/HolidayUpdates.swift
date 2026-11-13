import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class HolidayUpdates {
    private(set) var schedules = SharedState.holidaySchedules
    private var failedChecks: [Int: Date] = [:]

    func refresh(around year: Int) async {
        for requestedYear in [year, year + 1] where CalendarDay.supportedYears.contains(requestedYear) {
            guard !Task.isCancelled else { return }
            let now = Date.now
            if let checkedAt = schedules[requestedYear]?.checkedAt,
               (0..<86_400).contains(now.timeIntervalSince(checkedAt)) { continue }
            if let failedAt = failedChecks[requestedYear],
               (0..<3_600).contains(now.timeIntervalSince(failedAt)) { continue }

            let days = await Self.download(year: requestedYear)
            guard !Task.isCancelled else { return }
            guard let days else {
                failedChecks[requestedYear] = .now
                continue
            }

            let changed = schedules[requestedYear]?.days != days
            schedules[requestedYear] = .init(days: days, checkedAt: .now)
            SharedState.saveHolidaySchedules(schedules)
            failedChecks.removeValue(forKey: requestedYear)
            if changed { WidgetCenter.shared.reloadTimelines(ofKind: SharedState.widgetKind) }
        }
    }

    private static func download(year: Int) async -> [String: MainlandHolidays.Mark]? {
        let sources = [
            "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master",
            "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master",
        ]
        for source in sources {
            guard !Task.isCancelled else { return nil }
            guard let url = URL(string: "\(source)/\(year).json") else { continue }
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            if let (data, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let marks = HolidayFeed.marks(from: data, for: year) {
                return marks
            }
        }
        return nil
    }
}

struct HolidayFeed: Decodable {
    private struct Day: Decodable {
        let name: String
        let date: String
        let isOffDay: Bool
    }

    private let year: Int
    private let papers: [URL]
    private let days: [Day]

    static func marks(from data: Data, for year: Int) -> [String: MainlandHolidays.Mark]? {
        guard data.count <= 65_536,
              let feed = try? JSONDecoder().decode(Self.self, from: data),
              feed.year == year, feed.papers.contains(where: isGovernmentNotice) else { return nil }

        var marks: [String: MainlandHolidays.Mark] = [:]
        for day in feed.days {
            let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let date = CalendarDay(day.date), marks[day.date] == nil,
                  !name.isEmpty, name.count <= 40,
                  date.year == year || (date.year == year - 1 && date.month == 12) else { return nil }
            marks[day.date] = day.isOffDay ? .rest(name) : .work
        }
        // Future years may exist in the feed as empty placeholders.
        guard feed.days.contains(where: { $0.isOffDay && $0.date.hasPrefix("\(year)-") }) else { return nil }
        return marks
    }

    private static func isGovernmentNotice(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              url.scheme == "https" || url.scheme == "http" else { return false }
        return host == "gov.cn" || host.hasSuffix(".gov.cn")
    }
}
