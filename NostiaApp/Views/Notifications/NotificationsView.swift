import SwiftUI

struct NotificationsView: View {
    @StateObject private var vm = NotificationsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if vm.unreadCount > 0 {
                HStack {
                    Text("\(vm.unreadCount) unread")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                    Spacer()
                    Button("Mark all as read") { Task { await vm.markAllAsRead() } }
                        .font(.footnote.bold()).foregroundColor(Color.nostiaAccent)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .overlay(Divider().background(Color.white.opacity(0.1)), alignment: .bottom)
            }

            if vm.isLoading {
                LoadingView()
            } else {
                List(vm.notifications) { notif in
                    NotificationRow(notification: notif) {
                        Task { await vm.markAsRead(notif.id) }
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                .refreshable { await vm.load() }
                .overlay {
                    if vm.notifications.isEmpty {
                        EmptyStateView(icon: "bell.slash", text: "No notifications", sub: "You're all caught up!")
                    }
                }
            }
        }
        .background(.clear)
        .task { await vm.load() }
    }
}

struct NotificationRow: View {
    let notification: NostiaNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.iconName)
                    .font(.title3)
                    .foregroundColor(Color(hex: notification.iconColorHex))
                    .frame(width: 48, height: 48)
                    .glassEffect(in: Circle())
                    .overlay(Circle().stroke(Color(hex: notification.iconColorHex).opacity(0.3), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title).font(.headline).foregroundColor(.white)
                    Text(notification.body).font(.footnote).foregroundColor(Color(hex: "D1D5DB")).lineLimit(2)
                    Text(notification.timeAgo).font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
                Spacer()
                if !notification.read {
                    Circle().fill(Color.nostiaAccent).frame(width: 10, height: 10)
                        .shadow(color: Color.nostiaAccent.opacity(0.6), radius: 4)
                }
            }
            .padding(16)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                notification.read ? nil :
                RoundedRectangle(cornerRadius: 16).stroke(Color.nostiaAccent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
