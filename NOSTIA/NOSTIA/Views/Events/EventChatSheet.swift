import SwiftUI

/// Per-event chat thread. Reuses the post-comments UI (`CommentRow` / `FeedComment`)
/// backed by the event_comments endpoints. Opens from EventDetailSheet.
struct EventChatSheet: View {
    let eventId: Int
    @StateObject private var vm = EventChatViewModel()
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var currentUserId: Int? { AuthManager.shared.currentUserId }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView().tint(Color.nostiaAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.comments.isEmpty {
                    EmptyStateView(icon: "bubble.left.and.bubble.right",
                                   text: "No messages yet",
                                   sub: "Start the conversation for this event!")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: responsive.spacing(12)) {
                                ForEach(vm.comments) { comment in
                                    CommentRow(
                                        comment: comment,
                                        onReport: comment.userId == currentUserId ? nil : {
                                            vm.reportTarget = ReportTarget(contentType: "event_comment", contentId: comment.id)
                                        },
                                        onBlockUser: comment.userId == currentUserId ? nil : {
                                            Task { await vm.blockUser(userId: comment.userId, username: comment.username) }
                                        }
                                    )
                                }
                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(responsive.spacing(16))
                            .frame(maxWidth: responsive.sheetMaxWidth)
                            .frame(maxWidth: .infinity)
                        }
                        .onChange(of: vm.comments.count) {
                            withAnimation { proxy.scrollTo("bottom") }
                        }
                    }
                }
            }
            .background(.clear)
            .navigationTitle("Event Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { inputFocused = false; dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                TextField("Message...", text: $vm.newComment, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(10))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                    .foregroundColor(.white)
                    .focused($inputFocused)
                Button {
                    Haptics.tap()
                    Task { await vm.submit(eventId: eventId) }
                } label: {
                    if vm.isSubmitting {
                        ProgressView().tint(.white).frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white).frame(width: 36, height: 36)
                            .background(
                                vm.newComment.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AnyShapeStyle(Color.nostiaTextMuted)
                                    : AnyShapeStyle(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 6)
                    }
                }
                .disabled(vm.newComment.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSubmitting)
            }
            .padding(.horizontal, responsive.spacing(12)).padding(.vertical, responsive.spacing(8))
            .background(.ultraThinMaterial.opacity(0.9))
        }
        .presentationBackground(.ultraThinMaterial)
        .task { await vm.initialize(eventId: eventId) }
        .onDisappear { vm.stopPolling() }
        .sheet(item: $vm.reportTarget) { target in
            ReportSheet(target: target)
        }
        .alert("Blocked", isPresented: Binding(
            get: { vm.moderationMessage != nil },
            set: { if !$0 { vm.moderationMessage = nil } }
        )) {
            Button("OK") { vm.moderationMessage = nil }
        } message: {
            Text(vm.moderationMessage ?? "")
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
