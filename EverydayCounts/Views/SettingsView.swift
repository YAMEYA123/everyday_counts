import SwiftUI

struct SettingsView: View {
    @State private var reminderDate = NotificationManager.shared.reminderDate
    @State private var isAuthorized = false
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("每日打卡提醒", isOn: Binding(
                        get: { isAuthorized },
                        set: { on in
                            if on { Task { await enableReminder() } }
                            else { NotificationManager.shared.cancelAllReminders() }
                        }
                    ))
                    .tint(.yellow)

                    if isAuthorized {
                        DatePicker("提醒时间", selection: $reminderDate, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderDate) { _, newVal in
                                NotificationManager.shared.reminderDate = newVal
                                NotificationManager.shared.scheduleDailyReminder()
                            }
                    }
                } header: {
                    Text("通知")
                } footer: {
                    if isAuthorized {
                        Text("每天未打卡时，在此时间发送提醒。打卡后当天提醒自动取消。")
                    } else {
                        Text("开启后需要允许通知权限。如已拒绝，请去「设置 → 通知 → EverydayCounts」手动开启。")
                    }
                }

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("理念")
                        Spacer()
                        Text("Every day, once. Every day counts.")
                            .foregroundStyle(.secondary).font(.caption)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("关于")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .alert("需要通知权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在「设置 → 通知 → EverydayCounts」中开启通知权限。")
        }
        .task { isAuthorized = await NotificationManager.shared.isAuthorized() }
    }

    private func enableReminder() async {
        let ok = await NotificationManager.shared.requestPermission()
        if ok {
            isAuthorized = true
            NotificationManager.shared.scheduleDailyReminder()
        } else {
            isAuthorized = false
            showPermissionAlert = true
        }
    }
}
