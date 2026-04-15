import SwiftUI
import MapKit

struct FriendsMapView: View {
    @State private var friendLocations: [FriendLocation] = []
    @State private var isLoading = false
    @State private var cameraPosition = MapCameraPosition.automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(friendLocations) { friend in
                    Annotation(friend.name, coordinate: CLLocationCoordinate2D(
                        latitude: friend.latitude,
                        longitude: friend.longitude
                    )) {
                        VStack(spacing: 4) {
                            AvatarView(initial: String(friend.name.prefix(1)).uppercased(),
                                       color: Color.nostiaAccent, size: 36)
                                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                                .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 8)
                            Text(friend.name.components(separatedBy: " ").first ?? friend.name)
                                .font(.caption.bold()).foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .glassEffect(in: Capsule())
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                ProgressView().tint(Color.nostiaAccent)
                    .padding(16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            }

            if !isLoading && friendLocations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map").font(.system(size: 48)).foregroundColor(Color.nostiaAccent.opacity(0.8))
                    Text("No friend locations").font(.headline).foregroundColor(.white)
                    Text("Friends who share their location will appear here")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
        .task { await loadLocations() }
    }

    func loadLocations() async {
        isLoading = true
        if let locations = try? await FriendsAPI.shared.getLocations() {
            friendLocations = locations
        }
        isLoading = false
    }
}
