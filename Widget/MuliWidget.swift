import AppIntents
import SwiftUI
import WidgetKit

struct MonthEntry: TimelineEntry {
    let date: Date
    let today: CalendarDay
    let selection: CalendarDay
    let appearance: Appearance
    let dots: [String: [ScheduleColor]]
    let holidaySchedules: MainlandHolidays.DownloadedSchedules
}

struct MonthTimeline: TimelineProvider {
    func placeholder(in context: Context) -> MonthEntry {
        let day = CalendarDay.today
        return MonthEntry(
            date: .now, today: day, selection: day, appearance: Appearance(),
            dots: [:], holidaySchedules: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthEntry>) -> Void) {
        let now = Date.now
        let nextMidnight = CalendarDay(now).addingDays(1).start(in: CalendarDay.gregorian())
        completion(Timeline(entries: [entry(at: now), entry(at: nextMidnight)], policy: .after(nextMidnight)))
    }

    private func entry(at instant: Date) -> MonthEntry {
        let today = CalendarDay(instant)
        return MonthEntry(
            date: instant,
            today: today,
            selection: SharedState.widgetSelection ?? today,
            appearance: SharedState.appearance,
            dots: SharedState.eventDots,
            holidaySchedules: SharedState.holidaySchedules
        )
    }
}

struct WidgetMonthView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: MonthEntry

    private var palette: CalendarPalette { CalendarPalette(appearance: entry.appearance, scheme: colorScheme) }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                MonthHeader {
                    monthButton(-1)
                } title: {
                    Link(destination: CalendarRoute.picker(entry.selection).url) {
                        MonthTitle(date: entry.selection, palette: palette, compact: true)
                    }
                    .buttonStyle(.plain)
                } next: {
                    monthButton(1)
                } trailing: {
                    Text(LunarDate(entry.selection).header)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(height: 30)

                MonthGrid(
                    dates: entry.selection.monthGrid(), palette: palette,
                    rowHeight: max(30, (geometry.size.height - 65) / 6)
                ) { date in
                    let cell = CalendarCell(
                        date: date, selected: entry.selection, today: entry.today,
                        dots: entry.dots[date.id, default: []], holidaySchedules: entry.holidaySchedules,
                        palette: palette, compact: true
                    )
                    if date.isSupported {
                        Link(destination: CalendarRoute.day(date).url) { cell }
                            .buttonStyle(.plain)
                    } else {
                        cell
                    }
                }
            }
        }
        .padding(11)
        .containerBackground(for: .widget) { palette.paper }
        .widgetURL(CalendarRoute.day(entry.selection).url)
    }

    private func monthButton(_ offset: Int) -> some View {
        let date = entry.selection.addingMonths(offset)
        return Button(intent: MoveMonthIntent(date)) {
            MonthArrow(previous: offset < 0, palette: palette, compact: true)
        }
        .buttonStyle(.plain)
        .disabled(!date.isSupported)
    }
}

@main
struct MuliWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedState.widgetKind, provider: MonthTimeline()) { entry in
            WidgetMonthView(entry: entry)
        }
        .configurationDisplayName("木历月历")
        .description("浏览公历、农历、节气、调休和日程。")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}
