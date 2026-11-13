import CoreGraphics
import EventKit
import Foundation
import Observation
import WidgetKit

struct AgendaEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let calendarTitle: String
    let color: ScheduleColor

    init(_ event: EKEvent) {
        id = "\(event.calendarItemIdentifier):\(event.startDate.timeIntervalSinceReferenceDate)"
        title = event.title?.isEmpty == false ? event.title : "无标题日程"
        start = event.startDate
        end = event.endDate
        allDay = event.isAllDay
        calendarTitle = event.calendar.title
        color = ScheduleColor(event.calendar.cgColor)
    }

    func timeLabel(on date: CalendarDay) -> String {
        if allDay { return "全天" }
        let calendar = CalendarDay.gregorian()
        let startOfDay = date.start(in: calendar)
        let endOfDay = date.addingDays(1).start(in: calendar)
        let startLabel = start < startOfDay ? "00:00" : Self.clock(start)
        let endLabel = end >= endOfDay ? "24:00" : Self.clock(end)
        return "\(startLabel)–\(endLabel)"
    }

    private static func clock(_ date: Date) -> String {
        let components = CalendarDay.gregorian().dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour!, components.minute!)
    }
}

private extension ScheduleColor {
    init(_ color: CGColor?) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let components = color?.converted(to: space, intent: .defaultIntent, options: nil)?.components,
              components.count >= 3 else {
            self = .fallback
            return
        }
        func component(_ value: CGFloat) -> UInt8 {
            UInt8((min(1, max(0, value)) * 255).rounded())
        }
        self.init(red: component(components[0]), green: component(components[1]), blue: component(components[2]))
    }
}

@MainActor
@Observable
final class SystemCalendar {
    enum Access: Equatable {
        case available, requestable, restricted
    }

    struct Source: Identifiable {
        let id: String
        let title: String
        let account: String
        let color: ScheduleColor
    }

    private let store = EKEventStore()
    private let selectedCalendarsKey = "selectedCalendarIDs"
    private var selectedIDs: Set<String>?
    private var activeIDs: Set<String> = []
    private var eventsByDay: [CalendarDay: [AgendaEvent]] = [:]
    private var cachedDays: ClosedRange<CalendarDay>?
    private var extraMonth: CalendarDay?

    private(set) var sources: [Source] = []
    private(set) var access: Access = .requestable
    private(set) var isRequesting = false

    init() {
        if let ids = UserDefaults.standard.stringArray(forKey: selectedCalendarsKey) {
            selectedIDs = Set(ids)
        }
    }

    func requestAccess(showing date: CalendarDay) async {
        guard access == .requestable, !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            NSLog("Muli could not request calendar access: %@", error.localizedDescription)
        }
        refresh(showing: date)
    }

    func refresh(showing date: CalendarDay, today: CalendarDay = .today) {
        cachedDays = nil
        extraMonth = nil
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .available
        case .notDetermined, .writeOnly: access = .requestable
        default: access = .restricted
        }

        guard access == .available else {
            sources = []
            activeIDs = []
            eventsByDay = [:]
            publish([:])
            return
        }

        let calendars = store.calendars(for: .event)
        sources = calendars.map {
            Source(id: $0.calendarIdentifier, title: $0.title, account: $0.source.title, color: ScheduleColor($0.cgColor))
        }.sorted {
            ($0.account, $0.title, $0.id) < ($1.account, $1.title, $1.id)
        }
        let enabled = calendars.filter { calendar in
            if let selectedIDs { return selectedIDs.contains(calendar.calendarIdentifier) }
            return calendar.type != .subscription
        }
        activeIDs = Set(enabled.map(\.calendarIdentifier))

        guard !enabled.isEmpty else {
            eventsByDay = [:]
            publish([:])
            return
        }

        let local = CalendarDay.gregorian()
        // Cache the grid for the current month and its three neighbors on either side.
        let cacheFirst = today.monthStart.addingMonths(-3).monthGrid().first!
        let cacheLast = today.monthStart.addingMonths(3).monthGrid().last!
        cachedDays = cacheFirst...cacheLast
        var results = load(from: cacheFirst, through: cacheLast, calendars: enabled, local: local)
        let visible = date.monthGrid()
        if visible.first! < cacheFirst || visible.last! > cacheLast {
            extraMonth = date.monthStart
            results.merge(load(from: visible.first!, through: visible.last!, calendars: enabled, local: local)) { _, visibleEvents in
                visibleEvents
            }
        }
        eventsByDay = results
        let widgetDots = Dictionary(uniqueKeysWithValues: results.map { ($0.key.id, colors(for: $0.value)) })
        publish(widgetDots)
    }

    func showMonth(containing date: CalendarDay, today: CalendarDay) {
        guard let cachedDays, date.monthStart != extraMonth else { return }
        let grid = date.monthGrid()
        if !cachedDays.contains(grid.first!) || !cachedDays.contains(grid.last!) {
            refresh(showing: date, today: today)
        }
    }

    func events(on date: CalendarDay) -> [AgendaEvent] { eventsByDay[date, default: []] }

    func dots(on date: CalendarDay) -> [ScheduleColor] { colors(for: events(on: date)) }

    func isEnabled(_ source: Source) -> Bool { activeIDs.contains(source.id) }

    func setEnabled(_ enabled: Bool, for source: Source, showing date: CalendarDay) {
        var ids = activeIDs
        if enabled { ids.insert(source.id) } else { ids.remove(source.id) }
        selectedIDs = ids
        UserDefaults.standard.set(ids.sorted(), forKey: selectedCalendarsKey)
        refresh(showing: date)
    }

    private func load(
        from first: CalendarDay,
        through last: CalendarDay,
        calendars: [EKCalendar],
        local: Calendar
    ) -> [CalendarDay: [AgendaEvent]] {
        let rangeStart = first.start(in: local)
        let rangeEnd = last.addingDays(1).start(in: local)
        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: calendars)
        let events = store.events(matching: predicate).map(AgendaEvent.init).sorted {
            if $0.allDay != $1.allDay { return $0.allDay }
            return ($0.start, $0.end, $0.id) < ($1.start, $1.end, $1.id)
        }

        var byDay: [CalendarDay: [AgendaEvent]] = [:]
        for event in events where event.start < rangeEnd && max(event.end, event.start) >= rangeStart {
            var date = max(first, CalendarDay(event.start, in: local))
            while date <= last {
                let dayStart = date.start(in: local)
                if event.end <= dayStart && event.start < dayStart { break }
                byDay[date, default: []].append(event)
                date = date.addingDays(1)
            }
        }
        return byDay
    }

    private func colors(for events: [AgendaEvent]) -> [ScheduleColor] {
        var seen: Set<ScheduleColor> = []
        return Array(events.lazy.map(\.color).filter { seen.insert($0).inserted }.prefix(3))
    }

    private func publish(_ dots: [String: [ScheduleColor]]) {
        guard dots != SharedState.eventDots else { return }
        SharedState.saveEventDots(dots)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedState.widgetKind)
    }
}
