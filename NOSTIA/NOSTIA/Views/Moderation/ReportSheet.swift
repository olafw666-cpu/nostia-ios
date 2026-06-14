import SwiftUI

// Reusable content-flagging sheet (App Store Guideline 1.2).
// Present via .sheet(item:) with a ReportTarget.
struct ReportSheet: View {
    let target: ReportTarget
    var onSubmitted: (() -> Void)? = nil

    @State private var selectedReason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var titleText: String {
        switch target.contentType {
        case "post": return "Report Post"
        case "comment": return "Report Comment"
        case "event_comment": return "Report Message"
        case "message": return "Report Message"
        case "user": return "Report User"
        default: return "Report"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    VStack(spacing: responsive.spacing(14)) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: responsive.fontSize(52)))
                            .foregroundColor(Color.nostiaSuccess)
                        Text("Report submitted").font(.headline).foregroundColor(.white)
                        Text("Thank you for helping keep Nostia safe.\nWe review all reports within 24 hours.")
                            .font(.subheadline)
                            .foregroundColor(Color.nostiaTextSecond)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
                            if let err = errorMessage {
                                Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                            }

                            Text("Why are you reporting this?")
                                .font(.subheadline)
                                .foregroundColor(Color.nostiaTextSecond)

                            VStack(spacing: responsive.spacing(10)) {
                                ForEach(ReportReason.allCases) { reason in
                                    Button {
                                        selectedReason = reason
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: reason.icon)
                                                .foregroundColor(selectedReason == reason ? Color.nostiaAccent : Color.nostiaTextMuted)
                                                .frame(width: 24)
                                            Text(reason.displayName)
                                                .font(.system(size: responsive.fontSize(15), weight: .medium))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedReason == reason ? Color.nostiaAccent : Color.nostiaTextMuted)
                                        }
                                        .padding(responsive.spacing(14))
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedReason == reason ? Color.nostiaAccent.opacity(0.6) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if selectedReason == .other {
                                TextField("Tell us more (optional)...", text: $details, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(responsive.spacing(12))
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundColor(.white)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                HStack(spacing: 8) {
                                    if isSubmitting { ProgressView().tint(.white) }
                                    else { Image(systemName: "flag.fill"); Text("Submit Report") }
                                }
                                .font(.system(size: responsive.fontSize(16), weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(responsive.spacing(14))
                                .background(
                                    selectedReason == nil
                                        ? AnyShapeStyle(Color.nostiaTextMuted)
                                        : AnyShapeStyle(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                                       startPoint: .leading, endPoint: .trailing))
                                )
                                .cornerRadius(14)
                            }
                            .disabled(selectedReason == nil || isSubmitting)
                        }
                        .padding(responsive.spacing(16))
                        .frame(maxWidth: responsive.sheetMaxWidth)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(.clear)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(submitted ? "Done" : "Cancel") { dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
    }

    private func submit() async {
        guard let reason = selectedReason, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await ModerationAPI.shared.report(
                contentType: target.contentType,
                contentId: target.contentId,
                reason: reason,
                details: details
            )
            submitted = true
            onSubmitted?()
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
