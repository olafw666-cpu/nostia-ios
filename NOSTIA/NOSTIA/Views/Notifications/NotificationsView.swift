import SwiftUI

struct NotificationsView: View {
    @StateObject private var vm = NotificationsViewModel()
    @State private var showClearAllConfirm = false
    @EnvironmentObject var responsive: ResponsiveLayoutManager

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
                .padding(.horizontal, responsive.spacing(16)).padding(.vertical, responsive.spacing(12))
                .overlay(Divider().background(Color.nostiaDivider), alignment: .bottom)
            }

            if vm.isLoading && vm.notifications.isEmpty {
                NotificationSkeletonView()
            } else {
                List(vm.notifications) { notif in
                    NotificationRow(notification: notif) {
                        Task { await vm.markAsRead(notif.id) }
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: responsive.spacing(16), bottom: 4, trailing: responsive.spacing(16)))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(notif.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
        .toolbar {
            if !vm.notifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", role: .destructive) { showClearAllConfirm = true }
                        .foregroundColor(Color.nostriaDanger)
                }
            }
        }
        .confirmationDialog("Delete all notifications?", isPresented: $showClearAllConfirm, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) { Task { await vm.deleteAll() } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct NotificationRow: View {
    let notification: NostiaNotification
    let onTap: () -> Void
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.iconName)
                    .font(.title3)
                    .foregroundColor(Color(hex: notification.iconColorHex))
                    .frame(width: responsive.spacing(48), height: responsive.spacing(48))
                    .nostiaCard(in: Circle())
                    .overlay(Circle().stroke(Color(hex: notification.iconColorHex).opacity(0.3), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                    Text(notification.body).font(.footnote).foregroundColor(Color.nostiaTextSecond).lineLimit(2)
                    Text(notification.timeAgo).font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
                Spacer()
                if !notification.read {
                    Circle().fill(Color.nostiaAccent).frame(width: 10, height: 10)
                        .shadow(color: Color.nostiaAccent.opacity(0.6), radius: 4)
                }
            }
            .padding(responsive.spacing(16))
            .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                notification.read ? nil :
                RoundedRectangle(cornerRadius: 16).stroke(Color.nostiaAccent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
