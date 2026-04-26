import SwiftUI
import CoreImage.CIFilterBuiltins

struct VaultQRView: View {
    let trip: Trip

    @State private var token: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let token, let qr = generateQRCode(from: token) {
                    VStack(spacing: 16) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.nostiaAccent.opacity(0.3), radius: 16)

                        Text("Valid for 7 days")
                            .font(.caption)
                            .foregroundColor(Color.nostiaTextSecond)

                        Button {
                            Task { await loadToken() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.footnote.bold())
                                .foregroundColor(Color.nostiaAccent)
                        }
                    }
                } else if let err = errorMessage {
                    EmptyStateView(icon: "qrcode", text: "Could not load QR", sub: err)
                }

                Spacer()

                Text("Anyone who scans this with Nostia will join \"\(trip.title)\"")
                    .font(.footnote)
                    .foregroundColor(Color.nostiaTextSecond)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 32)
            .background(.clear)
            .navigationTitle(trip.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
            .task { await loadToken() }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func loadToken() async {
        isLoading = true
        errorMessage = nil
        do {
            token = try await TripsAPI.shared.getInviteToken(tripId: trip.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ci = filter.outputImage else { return nil }
        // Scale up to 660px before handing to SwiftUI — resizable() on a 33px bitmap blurs even with .interpolation(.none)
        let scale = 660.0 / ci.extent.width
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
