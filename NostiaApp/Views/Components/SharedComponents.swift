import SwiftUI

// MARK: - Avatar View

struct AvatarView: View {
    let initial: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(color.opacity(0.85))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: color.opacity(0.45), radius: size * 0.18)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView().tint(Color.nostiaAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let text: String
    let sub: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.nostiaAccent.opacity(0.7))
            Text(text).font(.title3.bold()).foregroundColor(.white)
            if !sub.isEmpty {
                Text(sub)
                    .font(.subheadline)
                    .foregroundColor(Color.nostiaTextSecond)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

// MARK: - Consent Sheet

struct ConsentSheet: View {
    let onConsent: (Bool, Bool) -> Void
    let onDecline: () -> Void

    @State private var locationConsent = true
    @State private var dataCollectionConsent = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Before you join Nostia, we need your consent to use certain features.")
                        .font(.subheadline).foregroundColor(Color.nostiaTextSecond)

                    ConsentToggle(
                        icon: "location.fill",
                        title: "Location Services",
                        description: "Nostia uses your location to show nearby events and share your position with friends. You can change this at any time.",
                        isOn: $locationConsent
                    )

                    ConsentToggle(
                        icon: "chart.bar.fill",
                        title: "Data Collection",
                        description: "We collect usage data to improve the app experience. All data is anonymized and never sold to third parties.",
                        isOn: $dataCollectionConsent
                    )

                    Text("By tapping \"I Agree\", you confirm you've read and accept our Privacy Policy.")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        Button {
                            onConsent(locationConsent, dataCollectionConsent)
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("I Agree")
                            }
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(16)
                            .background(
                                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                        }

                        Button {
                            onDecline()
                        } label: {
                            Text("Decline")
                                .font(.headline).foregroundColor(Color.nostiaTextSecond)
                                .frame(maxWidth: .infinity).padding(16)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(24)
            }
            .background(.clear)
            .navigationTitle("Privacy Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

struct ConsentToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(Color.nostiaAccent)
                Text(title).font(.headline).foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $isOn).tint(Color.nostiaAccent).labelsHidden()
            }
            Text(description).font(.footnote).foregroundColor(Color.nostiaTextSecond)
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Date helpers (used by trip sheets)

func formatTripDate(_ raw: String) -> String {
    let digits = String(raw.filter { $0.isNumber }.prefix(8))
    switch digits.count {
    case 0...4: return digits
    case 5...6: return "\(digits.prefix(4))-\(digits.dropFirst(4))"
    default:
        return "\(digits.prefix(4))-\(digits.dropFirst(4).prefix(2))-\(digits.dropFirst(6))"
    }
}

func isValidTripDate(_ value: String) -> Bool {
    guard value.count == 10 else { return false }
    let parts = value.split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return false }
    var comps = DateComponents()
    comps.year = y; comps.month = m; comps.day = d
    return Calendar.current.date(from: comps).map {
        Calendar.current.component(.year, from: $0) == y &&
        Calendar.current.component(.month, from: $0) == m &&
        Calendar.current.component(.day, from: $0) == d
    } ?? false
}

// MARK: - Create Trip Sheet

struct CreateTripSheet: View {
    let onSave: (String, String, String?, String?, String?) async -> Void

    @State private var title = ""
    @State private var destination = ""
    @State private var description = ""
    @State private var startDate = ""
    @State private var endDate = ""
    @State private var isSaving = false
    @State private var validationError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NostiaTextField(label: "Title *", placeholder: "Trip title", text: $title)
                    NostiaTextField(label: "Destination *", placeholder: "Where are you going?", text: $destination)
                    NostiaTextField(label: "Start Date *", placeholder: "YYYY-MM-DD", text: $startDate, keyboardType: .numberPad)
                        .onChange(of: startDate) { newValue in
                            let formatted = formatTripDate(newValue)
                            if formatted != newValue { startDate = formatted }
                        }
                    NostiaTextField(label: "End Date *", placeholder: "YYYY-MM-DD", text: $endDate, keyboardType: .numberPad)
                        .onChange(of: endDate) { newValue in
                            let formatted = formatTripDate(newValue)
                            if formatted != newValue { endDate = formatted }
                        }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        TextEditor(text: $description)
                            .frame(minHeight: 80).padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(.white).scrollContentBackground(.hidden)
                    }
                    if let err = validationError {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Create Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        validationError = nil
                        if !startDate.isEmpty && !isValidTripDate(startDate) {
                            validationError = "Start date is not a valid date."; return
                        }
                        if !endDate.isEmpty && !isValidTripDate(endDate) {
                            validationError = "End date is not a valid date."; return
                        }
                        if !startDate.isEmpty && !endDate.isEmpty && endDate < startDate {
                            validationError = "End date must be on or after start date."; return
                        }
                        isSaving = true
                        Task {
                            await onSave(title, destination,
                                         description.isEmpty ? nil : description,
                                         startDate.isEmpty ? nil : startDate,
                                         endDate.isEmpty ? nil : endDate)
                            isSaving = false
                        }
                    } label: {
                        if isSaving { ProgressView().tint(Color.nostiaAccent) }
                        else { Text("Create").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                    }
                    .disabled(title.isEmpty || destination.isEmpty || isSaving)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Create Expense Sheet

struct CreateExpenseSheet: View {
    let tripId: Int
    let onSave: (String, Double, String?, String) async -> Void

    @State private var description = ""
    @State private var amountText = ""
    @State private var category = ""
    @State private var dateText = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    let categories = ["Food", "Transport", "Accommodation", "Activities", "Shopping", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NostiaTextField(label: "Description *", placeholder: "What was this for?", text: $description)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount *")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        HStack {
                            Text("$").foregroundColor(Color.nostiaTextSecond).font(.title3)
                            TextField("0.00", text: $amountText).keyboardType(.decimalPad).foregroundColor(.white)
                        }
                        .padding(16)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }

                    NostiaTextField(label: "Date *", placeholder: "YYYY-MM-DD", text: $dateText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    FilterChip(title: cat, isActive: category == cat) { category = cat }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let amount = Double(amountText), amount > 0, !description.isEmpty, !dateText.isEmpty else { return }
                        isSaving = true
                        Task {
                            await onSave(description, amount, category.isEmpty ? nil : category, dateText)
                            isSaving = false
                        }
                    } label: {
                        if isSaving { ProgressView().tint(Color.nostiaAccent) }
                        else { Text("Add").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                    }
                    .disabled(description.isEmpty || amountText.isEmpty || dateText.isEmpty || isSaving)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            dateText = fmt.string(from: Date())
        }
    }
}

// MARK: - Filter Chip (shared across Adventures and Vault)

struct FilterChip: View {
    let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isActive ? .white : Color.nostiaTextSecond)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(in: Capsule())
                .overlay(isActive ? Capsule().stroke(Color.nostiaAccent, lineWidth: 1) : nil)
        }
    }
}
