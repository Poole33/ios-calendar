import AppIntents

struct MoveMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "切换木历月份"
    static let isDiscoverable = false

    @Parameter(title: "目标日期")
    var dateKey: String

    init() {}

    init(_ date: CalendarDay) {
        dateKey = date.id
    }

    func perform() async throws -> some IntentResult {
        if let date = CalendarDay(dateKey), date.isSupported {
            SharedState.saveWidgetSelection(date)
        }
        return .result()
    }
}
