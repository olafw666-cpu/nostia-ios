import SwiftUI

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Terms of Service")
                    .font(.nostiaBody(responsive.fontSize(20), weight: .bold))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, responsive.spacing(20))
                    .padding(.top, responsive.spacing(16))
                    .padding(.bottom, responsive.spacing(8))

                Text("Effective \(LegalDocuments.tosVersion)")
                    .font(.footnote)
                    .foregroundColor(Color.nostiaTextSecond)
                    .padding(.bottom, responsive.spacing(12))

                Divider().background(Color.nostriaBorder)
            }
            .background(.ultraThinMaterial)

            ScrollView {
                Text(LegalDocuments.termsOfUse)
                    .font(.system(size: max(13, responsive.fontSize(13))))
                    .foregroundColor(Color.nostiaTextSecond)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, responsive.spacing(20))
                    .padding(.vertical, responsive.spacing(20))
                    .frame(maxWidth: responsive.contentMaxWidth)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 0) {
                Divider().background(Color.nostriaBorder)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.nostiaBody(responsive.fontSize(17), weight: .bold))
                        .foregroundColor(Color.nostiaTextPrimary)
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
    }
}
