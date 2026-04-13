import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessage = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    private var currentUserId: Int?
    private var pollTask: Task<Void, Never>?

    func initialize(conversationId: Int) async {
        isLoading = true
        do {
            let user = try await AuthAPI.shared.getMe()
            currentUserId = user.id
            await loadMessages(conversationId: conversationId)
            try? await MessagesAPI.shared.markAsRead(conversationId: conversationId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        startPolling(conversationId: conversationId)
    }

    func loadMessages(conversationId: Int) async {
        do {
            let data = try await MessagesAPI.shared.getMessages(conversationId: conversationId, limit: 100, offset: 0)
            messages = data // oldest first (server returns newest first, reversed here)
        } catch {
            print("Message load error: \(error.localizedDescription)")
        }
    }

    func send(conversationId: Int) async {
        let content = newMessage.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        isSending = true
        newMessage = ""
        do {
            let msg = try await MessagesAPI.shared.sendMessage(conversationId: conversationId, content: content)
            messages.append(msg)
        } catch {
            errorMessage = error.localizedDescription
            newMessage = content // Restore on failure
        }
        isSending = false
    }

    func isFromMe(_ message: Message) -> Bool {
        message.senderId == currentUserId
    }

    func startPolling(conversationId: Int) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled {
                    await loadMessages(conversationId: conversationId)
                }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
