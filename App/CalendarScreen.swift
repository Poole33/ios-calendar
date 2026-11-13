import EventKit
import SwiftUI
import WidgetKit

struct CalendarScreen: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var today = CalendarDay.today
    @ViewState private var selection: CalendarDay?
    @ViewState private var appearance = SharedState.appearance
    @ViewState private var systemCalendar = SystemCalendar()
    @ViewState private var sheet: Sheet?

    private enum Sheet: Identifiable {
        case date(CalendarDay, syncWidget: Bool)
        case settings

        var id: String {
            switch self {
            case .date: "date"
            case .settings: "settings"
            }
        }
    }

    private var selected: CalendarDay { selection ?? today }
    private var palette: CalendarPalette { CalendarPalette(appearance: appearance, scheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                monthHeader
                    .padding(.bottom, 7)
                MonthGrid(dates: selected.monthGrid(), palette: palette, rowHeight: 44) { date in
                    let cell = CalendarCell(
                        date: date, selected: selected, today: today,
                        dots: systemCalendar.dots(on: date), palette: palette, compact: false
                    )
                    if date.isSupported {
                        Button { select(date) } label: { cell }
                            .buttonStyle(.plain)
                    } else {
                        cell
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 28).onEnded { value in
                        let x = value.translation.width
                        let y = value.translation.height
                        if abs(x) > abs(y) && abs(x) >= 42 {
                            select(selected.addingMonths(x < 0 ? 1 : -1))
                        }
                    }
                )
                .padding(.bottom, 8)

                AgendaView(date: selected, palette: palette, calendar: systemCalendar)
                    .padding(.horizontal, -14)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .frame(maxWidth: 550)
            .frame(maxWidth: .infinity)
        }
        .background(palette.paper.ignoresSafeArea())
        .tint(palette.accent)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .date(let date, let syncWidget):
                DateJumpSheet(initialDate: date, today: today) { date in
                    select(date)
                    if syncWidget { updateWidgetSelection(date) }
                }
            case .settings:
                SettingsSheet(appearance: $appearance, date: selected, calendar: systemCalendar)
            }
        }
        .onOpenURL(perform: open)
        .onChange(of: selected.monthStart) {
            systemCalendar.showMonth(containing: selected, today: today)
        }
        .onChange(of: appearance) {
            SharedState.saveAppearance(appearance)
            WidgetCenter.shared.reloadTimelines(ofKind: SharedState.widgetKind)
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            systemCalendar.refresh(showing: selected, today: today)
        }
        .task(id: phase) {
            guard phase == .active else { return }
            while !Task.isCancelled {
                today = .today
                systemCalendar.refresh(showing: selected, today: today)
                let midnight = today.addingDays(1).start(in: CalendarDay.gregorian())
                do {
                    try await Task.sleep(for: .seconds(max(1, midnight.timeIntervalSinceNow)))
                } catch {
                    return
                }
            }
        }
    }

    private var monthHeader: some View {
        MonthHeader {
            monthButton(-1)
        } title: {
            MonthTitle(date: selected, palette: palette, compact: false)
                .gesture(
                    LongPressGesture(minimumDuration: 0.55).exclusively(before: TapGesture())
                        .onEnded { gesture in
                            switch gesture {
                            case .first: select(today)
                            case .second: openPicker()
                            }
                        }
                )
                .focusable()
                .onKeyPress(.return) {
                    openPicker()
                    return .handled
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openPicker() }
                .accessibilityAction(named: Text("回到今天")) { select(today) }
        } next: {
            monthButton(1)
        } trailing: {
            Button {
                if selected == today { sheet = .settings }
                else { select(today) }
            } label: {
                Text(selected == today ? "木历" : "今")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minWidth: 38, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected == today ? "木历，打开设置" : "今，回到今天")
        }
    }

    private func monthButton(_ offset: Int) -> some View {
        let date = selected.addingMonths(offset)
        return Button { select(date) } label: {
            MonthArrow(previous: offset < 0, palette: palette, compact: false)
        }
        .buttonStyle(.plain)
        .disabled(!date.isSupported)
    }

    private func openPicker() {
        sheet = .date(selected, syncWidget: false)
    }

    private func select(_ date: CalendarDay) {
        guard date.isSupported else { return }
        selection = date == today ? nil : date
    }

    private func open(_ url: URL) {
        guard let route = CalendarRoute(url: url) else { return }
        today = .today
        select(route.date)
        switch route {
        case .day(let date):
            sheet = nil
            updateWidgetSelection(date)
        case .picker(let date):
            sheet = .date(date, syncWidget: true)
        }
    }

    private func updateWidgetSelection(_ date: CalendarDay) {
        SharedState.saveWidgetSelection(date, today: today)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedState.widgetKind)
    }
}
