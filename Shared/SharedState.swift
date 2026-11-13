import Foundation

struct Appearance: Codable, Equatable {
    enum Paper: String, CaseIterable, Codable, Identifiable {
        case white, mist, ivory
        var id: Self { self }
        var title: String {
            switch self {
            case .white: "清白"
            case .mist: "雾白"
            case .ivory: "米白"
            }
        }
    }

    enum Accent: String, CaseIterable, Codable, Identifiable {
        case moss, pine, slate
        var id: Self { self }
        var title: String {
            switch self {
            case .moss: "苔绿"
            case .pine: "松绿"
            case .slate: "岩蓝"
            }
        }
    }

    var paper: Paper = .white
    var accent: Accent = .moss
}

struct ScheduleColor: Codable, Hashable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let fallback = Self(red: 81, green: 123, blue: 171)
}

enum SharedState {
    static let widgetKind = "MuliMonthWidget"

    private static let directory: URL = {
        let files = FileManager.default
        if let identifier = Bundle.main.object(forInfoDictionaryKey: "MuliAppGroup") as? String,
           let group = files.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return group
        }
        return URL.applicationSupportDirectory.appending(path: "Muli", directoryHint: .isDirectory)
    }()

    static var appearance: Appearance {
        load(Appearance.self, from: "appearance.json") ?? Appearance()
    }

    static func saveAppearance(_ appearance: Appearance) {
        save(appearance, to: "appearance.json")
    }

    static var widgetSelection: CalendarDay? {
        guard let key = load(String.self, from: "widget-date.json"),
              let day = CalendarDay(key), day.isSupported else { return nil }
        return day
    }

    static func saveWidgetSelection(_ date: CalendarDay, today: CalendarDay = .today) {
        save(date == today ? "" : date.id, to: "widget-date.json")
    }

    static var eventDots: [String: [ScheduleColor]] {
        load([String: [ScheduleColor]].self, from: "event-dots.json") ?? [:]
    }

    static func saveEventDots(_ dots: [String: [ScheduleColor]]) {
        save(dots, to: "event-dots.json")
    }

    static var holidaySchedules: MainlandHolidays.DownloadedSchedules {
        load(MainlandHolidays.DownloadedSchedules.self, from: "holiday-schedules.json") ?? [:]
    }

    static func saveHolidaySchedules(_ schedules: MainlandHolidays.DownloadedSchedules) {
        save(schedules, to: "holiday-schedules.json")
    }

    private static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appending(path: name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appending(path: name), options: .atomic)
        } catch {
            // A missing shared container must not prevent browsing the calendar.
            NSLog("Muli shared state could not be saved (%@).", name)
        }
    }
}

enum CalendarRoute {
    case day(CalendarDay)
    case picker(CalendarDay)

    var date: CalendarDay {
        switch self {
        case .day(let date), .picker(let date): date
        }
    }

    var url: URL {
        let action: String
        switch self {
        case .day: action = "day"
        case .picker: action = "pick"
        }
        return URL(string: "muli://\(action)/\(date.id)")!
    }

    init?(url: URL) {
        guard url.scheme == "muli", url.pathComponents.count == 2,
              let date = CalendarDay(url.lastPathComponent), date.isSupported else { return nil }
        switch url.host {
        case "day": self = .day(date)
        case "pick": self = .picker(date)
        default: return nil
        }
    }
}
