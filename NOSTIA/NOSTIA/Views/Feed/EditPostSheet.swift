import SwiftUI

struct EditPostSheet: View {
    let post: FeedPost
    let feedVM: FeedViewModel

    @State private var content: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(post: FeedPost, feedVM: FeedViewModel) {
        self.post = post
        self.feedVM = feedVM
        self._content = State(initialValue: post.content ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                        .padding(12)
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(Color.nostiaTextPrimary)
                        .scrollContentBackground(.hidden)

                    if let err = errorMessage {
                        Text(err)
                            .font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.nostiaTextSecond)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSaving = true
                        Task {
                            await feedVM.editPost(post: post, newContent: content)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color.nostiaAccent)
                        } else {
                            Text("Save").fontWeight(.semibold).foregroundColor(Color.nostiaAccent)
                        }
                    }
                    .disabled(isSaving || content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }
}
