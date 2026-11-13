import SwiftUI

struct AgendaView: View {
    let date: CalendarDay
    let palette: CalendarPalette
    let calendar: SystemCalendar

    var body: some View {
        let info = DayInformation(date)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(date.month)月\(date.day)日 · \(date.weekdayName)")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 6)
                if let mark = info.holiday {
                    Text(mark.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            Text(detail(for: info))
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
            Text("当日日程")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)
            agenda
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.panel)
    }

    @ViewBuilder private var agenda: some View {
        let events = calendar.events(on: date)
        switch calendar.access {
        case .requestable:
            Button("连接系统日历") {
                Task { await calendar.requestAccess(showing: date) }
            }
            .buttonStyle(.bordered)
            .disabled(calendar.isRequesting)
        case .restricted:
            Text("在系统设置中允许木历访问日历后，即可查看当天的日程。")
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
        case .available:
            if events.isEmpty {
                Text("当天没有日程")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(events) { event in
                        eventRow(event)
                        if event.id != events.last?.id {
                            Rectangle().fill(palette.divider).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func detail(for info: DayInformation) -> String {
        let festival = info.festival
        let term = festival == "清明节" ? nil : info.solarTerm
        return [info.lunar.detail, festival, term].compactMap { $0 }.joined(separator: " · ")
    }

    private func eventRow(_ event: AgendaEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(event.color.color).frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(event.timeLabel(on: date))
                .font(.caption.monospacedDigit())
                .foregroundStyle(palette.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .foregroundStyle(palette.ink)
                Text(event.calendarTitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}
