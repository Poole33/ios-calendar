import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var appearance: Appearance
    let date: CalendarDay
    let calendar: SystemCalendar

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("底色", selection: $appearance.paper) {
                        ForEach(Appearance.Paper.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("选中颜色", selection: $appearance.accent) {
                        ForEach(Appearance.Accent.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
                Section("日程") {
                    switch calendar.access {
                    case .requestable:
                        Button("连接系统日历") {
                            Task { await calendar.requestAccess(showing: date) }
                        }
                        .disabled(calendar.isRequesting)
                    case .restricted:
                        Text("请在系统设置的日历隐私选项中允许木历访问日历。")
                            .foregroundStyle(.secondary)
                    case .available:
                        if calendar.sources.isEmpty {
                            Text("系统日历中暂无可用日历").foregroundStyle(.secondary)
                        } else {
                            ForEach(calendar.sources) { source in
                                Toggle(isOn: Binding(
                                    get: { calendar.isEnabled(source) },
                                    set: { calendar.setEnabled($0, for: source, showing: date) }
                                )) {
                                    HStack(spacing: 8) {
                                        Circle().fill(source.color.color).frame(width: 7, height: 7)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading) {
                                            Text(source.title)
                                            Text(source.account).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(width: 440, height: 470)
        #endif
    }
}
