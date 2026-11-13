import SwiftUI

struct DateJumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ViewState private var year: Int
    @ViewState private var month: Int
    @ViewState private var day: Int

    let today: CalendarDay
    let onSelect: (CalendarDay) -> Void

    init(initialDate: CalendarDay, today: CalendarDay, onSelect: @escaping (CalendarDay) -> Void) {
        _year = State(initialValue: initialDate.year)
        _month = State(initialValue: initialDate.month)
        _day = State(initialValue: initialDate.day)
        self.today = today
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 3) {
                    field("年", values: CalendarDay.supportedYears, value: $year)
                    field("月", values: 1...12, value: $month)
                    field("日", values: 1...lastDay, value: $day)
                }
                Button("今天") { finish(today) }
                    .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("跳转日期")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("跳转") {
                        if let date = CalendarDay(year, month, min(day, lastDay)) { finish(date) }
                    }
                }
            }
        }
        .onChange(of: lastDay) { day = min(day, lastDay) }
        #if os(macOS)
        .frame(width: 420, height: 165)
        #else
        .presentationDetents([.medium])
        #endif
    }

    private var lastDay: Int { CalendarDay.daysInMonth(year: year, month: month) }

    private func field(_ suffix: String, values: ClosedRange<Int>, value: Binding<Int>) -> some View {
        Picker(suffix, selection: value) {
            ForEach(values, id: \.self) { value in
                Text(String(value) + suffix).tag(value)
            }
        }
        .labelsHidden()
        #if os(iOS)
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
        #else
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
        #endif
    }

    private func finish(_ date: CalendarDay) {
        onSelect(date)
        dismiss()
    }
}
