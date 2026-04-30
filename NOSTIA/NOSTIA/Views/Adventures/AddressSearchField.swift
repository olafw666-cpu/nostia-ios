import SwiftUI
import MapKit

@Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet { completer.queryFragment = query }
    }
    var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ c: MKLocalSearchCompleter) {
        results = c.results
    }

    func completer(_ c: MKLocalSearchCompleter, didFailWithError e: Error) {
        results = []
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let req = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: req)
        let response = try? await search.start()
        return response?.mapItems.first?.placemark.coordinate
    }
}

struct AddressSearchField: View {
    @Binding var locationName: String
    let onSelect: (CLLocationCoordinate2D, String) -> Void

    @State private var completer = AddressCompleter()
    @State private var showResults = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.nostiaTextSecond)
                TextField("Search address or place…", text: $completer.query)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onChange(of: completer.query) { _, q in
                        locationName = q
                        showResults = !q.isEmpty
                    }
                if !completer.query.isEmpty {
                    Button {
                        completer.query = ""
                        locationName = ""
                        showResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.nostiaTextMuted)
                    }
                }
            }
            .padding(12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))

            if showResults && !completer.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.results.prefix(5), id: \.self) { result in
                        Button {
                            Task {
                                if let coord = await completer.resolve(result) {
                                    let name = result.title
                                    completer.query = name
                                    locationName = name
                                    showResults = false
                                    focused = false
                                    onSelect(coord, name)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(Color.nostiaTextSecond)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 4)
            }
        }
    }
}
