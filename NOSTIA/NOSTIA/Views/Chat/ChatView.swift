import SwiftUI

struct ChatView: View {
    let conversationId: Int
    let friendName: String
    var friendId: Int? = nil

    @StateObject private var vm = ChatViewModel()
    @State private var scrollProxy: ScrollViewProxy?
    @State private var reportTarget: ReportTarget?
    @State private var showBlockConfirm = false
    @State private var blockedMessage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if vm.isLoading {
                            ProgressView().tint(Color.nostiaAccent).padding(40)
                        } else if vm.messages.isEmpty {
                            EmptyStateView(icon: "bubble.left.and.bubble.right",
                                           text: "No messages yet",
                                           sub: "Send a message to start the conversation!")
                                .padding(.top, 60)
                        } else {
                            ForEach(Array(vm.messages.enumerated()), id: \.element.id) { idx, msg in
                                let showDate = idx == 0 ||
                                    !Calendar.current.isDate(
                                        ISO8601DateFormatter().date(from: msg.createdAt) ?? Date(),
                                        inSameDayAs: ISO8601DateFormatter().date(from: vm.messages[idx - 1].createdAt) ?? Date()
                                    )
                                VStack(spacing: 0) {
                                    if showDate {
                                        Text(msg.dayString)
                                            .font(.caption).foregroundColor(Color.nostiaTextMuted)
                                            .padding(.horizontal, 12).padding(.vertical, 4)
                                            .nostiaCard(in: Capsule())
                                            .padding(.vertical, 12)
                                    }
                                    MessageBubble(message: msg, isFromMe: vm.isFromMe(msg))
                                }
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                }
                .onChange(of: vm.messages.count) {
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onAppear {
                    proxy.scrollTo("bottom")
                }
            }

            // Lock banner (shown when mutual follow is lost)
            if vm.isLocked {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").foregroundColor(.white)
                    Text("Read-only — mutual follow required to send messages")
                        .font(.caption).foregroundColor(.white)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.nostiaWarning.opacity(0.85))
            }

            // Input bar
            VStack(spacing: 0) {
                Divider().background(Color.nostiaDivider)
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Type a message...", text: $vm.newMessage, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 20))
                        .foregroundColor(Color.nostiaTextPrimary)
                        .disabled(vm.isLocked)

                    Button {
                        Task { await vm.send(conversationId: conversationId) }
                    } label: {
                        if vm.isSending {
                            ProgressView().tint(.white).frame(width: 44, height: 44)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    (vm.newMessage.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLocked)
                                        ? AnyShapeStyle(Color.nostiaDisabled)
                                        : AnyShapeStyle(LinearGradient(
                                            colors: [Color.nostiaAccent, Color.nostriaPurple],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                          ))
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.nostiaAccent.opacity(
                                    (vm.newMessage.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLocked) ? 0 : 0.4
                                ), radius: 8)
                        }
                    }
                    .disabled(vm.newMessage.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSending || vm.isLocked)
                }
                .padding(12)
                .background(.ultraThinMaterial)
            }
        }
        // Centered reading column on iPad's wide landscape canvas; full width on phone.
        .frame(maxWidth: responsive.contentMaxWidth)
        // The floating tab bar is hidden while the chat is open so it can't cover the
        // message input bar (the bar lives outside the tab's NavigationStack).
        .hidesAppTabBar()
        // Pushed destinations don't inherit the tab root's themed canvas — without this
        // the chat sits on the system background (black in dark mode).
        .background(Color.nostiaBackground.ignoresSafeArea())
        .navigationTitle(friendName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if let friendId {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            reportTarget = ReportTarget(contentType: "user", contentId: friendId)
                        } label: {
                            Label("Report User", systemImage: "flag")
                        }
                        Button(role: .destructive) { showBlockConfirm = true } label: {
                            Label("Block \(friendName)", systemImage: "nosign")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color.nostiaAccent)
                    }
                }
            }
        }
        .confirmationDialog(
            "Block \(friendName)? You won't see each other's posts, comments, or messages.",
            isPresented: $showBlockConfirm, titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task { await blockFriend() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target)
        }
        .alert("Blocked", isPresented: Binding(get: { blockedMessage != nil }, set: { if !$0 { blockedMessage = nil } })) {
            Button("OK") {
                blockedMessage = nil
                dismiss()
            }
        } message: { Text(blockedMessage ?? "") }
        .task { await vm.initialize(conversationId: conversationId) }
        .onDisappear { vm.stopPolling() }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
    }

    private func blockFriend() async {
        guard let friendId else { return }
        do {
            try await ModerationAPI.shared.blockUser(userId: friendId)
            vm.isLocked = true
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
            await CacheManager.shared.invalidate(CacheKey.followersList)
            await CacheManager.shared.invalidate(CacheKey.followingList)
            blockedMessage = "\(friendName) has been blocked"
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromMe: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromMe { Spacer(minLength: 60) }
            if !isFromMe {
                AvatarView(initial: String(message.senderName.prefix(1)).uppercased(),
                           color: Color.nostriaPurple, size: 28)
            }
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isFromMe ? .white : Color.nostiaTextPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(
                        isFromMe
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.nostiaAccent, Color.nostriaPurple],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(Color.clear)
                    )
                    .if(!isFromMe) { view in
                        view.nostiaCard(in: UnevenRoundedRectangle(
                            topLeadingRadius: 18, bottomLeadingRadius: 4,
                            bottomTrailingRadius: 18, topTrailingRadius: 18
                        ))
                    }
                    .if(isFromMe) { view in
                        view.clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 18, bottomLeadingRadius: 18,
                            bottomTrailingRadius: 4, topTrailingRadius: 18
                        ))
                        .shadow(color: Color.nostiaAccent.opacity(0.35), radius: 8, y: 4)
                    }

                Text(message.timeFormatted)
                    .font(.system(size: 10)).foregroundColor(Color.nostiaTextMuted)
            }
            if !isFromMe { Spacer(minLength: 60) }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View extension for conditional modifiers

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
