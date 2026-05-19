import SwiftUI

struct TermsAgreementView: View {
    let onAgree: () -> Void
    let onDecline: () -> Void

    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @State private var showDeclineConfirmation = false

    private struct DocumentSection: Identifiable {
        let id = UUID()
        let header: String
        let body: String
    }

    private let documents: [DocumentSection] = [
        DocumentSection(header: "Terms of Use",          body: LegalDocuments.termsOfUse),
        DocumentSection(header: "Privacy Policy",        body: LegalDocuments.privacyPolicy),
        DocumentSection(header: "Community Guidelines",  body: LegalDocuments.communityGuidelines)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            VStack(spacing: 0) {
                Text("Terms & Agreements")
                    .font(.system(size: responsive.fontSize(20), weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, responsive.spacing(20))
                    .padding(.top, responsive.spacing(16))
                    .padding(.bottom, responsive.spacing(8))

                Text("Please scroll through and read all agreements before proceeding.")
                    .font(.footnote)
                    .foregroundColor(Color.nostiaTextSecond)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: responsive.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, responsive.spacing(20))
                    .padding(.bottom, responsive.spacing(12))

                Divider().background(Color.nostriaBorder)
            }
            .background(.ultraThinMaterial)

            // Scrollable document body
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(documents.enumerated()), id: \.element.id) { index, doc in
                        VStack(alignment: .leading, spacing: responsive.spacing(10)) {
                            Text(doc.header)
                                .font(.system(size: responsive.fontSize(17), weight: .bold))
                                .foregroundColor(.white)

                            Text(doc.body)
                                .font(.system(size: max(13, responsive.fontSize(13))))
                                .foregroundColor(Color.nostiaTextSecond)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, responsive.spacing(20))

                        if index < documents.count - 1 {
                            Divider()
                                .background(Color.nostriaBorder)
                                .padding(.vertical, responsive.spacing(4))
                        }
                    }
                }
                .padding(.horizontal, responsive.spacing(20))
                .padding(.bottom, responsive.spacing(20))
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }

            // Fixed bottom bar
            VStack(spacing: 0) {
                Divider().background(Color.nostriaBorder)

                HStack(spacing: responsive.spacing(12)) {
                    Button {
                        showDeclineConfirmation = true
                    } label: {
                        Text("Decline")
                            .font(.system(size: responsive.fontSize(16), weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
                            .frame(minWidth: 44, minHeight: 44)
                            .padding(.horizontal, responsive.spacing(16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.nostriaBorder, lineWidth: 1)
                            )
                    }

                    Button {
                        onAgree()
                    } label: {
                        Text("Agree")
                            .font(.system(size: responsive.fontSize(17), weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding(.vertical, responsive.spacing(14))
                            .background(
                                LinearGradient(
                                    colors: [Color.nostiaAccent, Color.nostriaPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color.nostiaAccent.opacity(0.35), radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, responsive.spacing(20))
                .padding(.vertical, responsive.spacing(16))
                .padding(.bottom, responsive.spacing(4))
            }
            .background(.ultraThinMaterial)
        }
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "0C1120"), location: 0.0),
                    .init(color: Color(hex: "1A0E35"), location: 0.5),
                    .init(color: Color(hex: "0A1628"), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .confirmationDialog(
            "If you decline, you will not be able to use Nostia. Are you sure?",
            isPresented: $showDeclineConfirmation,
            titleVisibility: .visible
        ) {
            Button("Decline", role: .destructive) { onDecline() }
            Button("Stay", role: .cancel) {}
        }
    }
}
