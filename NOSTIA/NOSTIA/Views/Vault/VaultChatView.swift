import SwiftUI

struct VaultChatView: View {
    let tripId: Int
    let isKicked: Bool

    @State private var messages: [TripChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?

    private var currentUserId: Int? { AuthManager.shared.currentUserId }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                LoadingView()
            } else if messages.isEmpty {
                EmptyStateView(icon: "bubble.left.and.bubble.right", text: "No messages yet", sub: "Start the conversation!")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(messages) { msg in
                                VaultChatBubble(message: msg, isMe: msg.senderId == currentUserId)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundColor(Color.nostriaDanger)
                    .padding(.horizontal, 16).padding(.vertical, 4)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isKicked {
                HStack {
                    Image(systemName: "lock.fill").foregroundColor(Color.nostiaTextMuted).font(.caption)
                    Text("You were removed from this vault — read-only")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .glassEffect(in: RoundedRectangle(cornerRadius: 0))
            } else {
                HStack(spacing: 10) {
                    TextField("Message...", text: $inputText)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 22))
                    Button {
                        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task { await sendMessage() }
                    } label: {
                        if isSending {
                            ProgressView().tint(.white).frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(inputText.isEmpty ? Color.nostiaTextMuted : Color.nostiaAccent)
                        }
                    }
                    .disabled(inputText.isEmpty || isSending)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .task {
            await loadMessages()
        }
    }

    private func loadMessages() async {
        isLoading = true
        do {
            messages = try await TripsAPI.shared.getChatMessages(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        isSending = true
        do {
            let msg = try await TripsAPI.shared.sendChatMessage(tripId: tripId, content: text)
            messages.append(msg)
            errorMessage = nil
        } catch {
            inputText = text
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

struct VaultChatBubble: View {
    let message: TripChatMessage
    let isMe: Bool

    private var timeString: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmt2 = ISO8601DateFormatter()
        fmt2.formatOptions = [.withInternetDateTime]
        let date = fmt.date(from: message.createdAt) ?? fmt2.date(from: message.createdAt)
        guard let d = date else { return "" }
        let out = DateFormatter()
        out.dateFormat = "h:mm a"
        return out.string(from: d)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 40) }
            if !isMe {
                AvatarView(
                    initial: String((message.senderName ?? "U").prefix(1)).uppercased(),
                    color: Color.nostiaAccent, size: 30
                )
            }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                if !isMe, let name = message.senderName {
                    Text(name).font(.caption.bold()).foregroundColor(Color.nostiaTextSecond)
                }
                Text(message.content)
                    .font(.subheadline).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isMe ? Color.nostiaAccent : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Text(timeString).font(.system(size: 10)).foregroundColor(Color.nostiaTextMuted)
            }
            if !isMe { Spacer(minLength: 40) }
        }
    }
}
