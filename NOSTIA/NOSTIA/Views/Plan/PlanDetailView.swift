import SwiftUI

/// The plan artifact (Product Definition v2 §4.5): named, sequenced, timed —
/// stops with walking legs, not search results. Keep / reroll live on the same
/// screen so rejecting a plan costs one tap. Once the outing starts, each stop
/// carries the §6 verification flow: "I'm here" runs a foreground geofence
/// dwell (DwellVerifier), a confirmed stop can take an optional photo artifact,
/// and the one-tap rating unlocks only after a confirmed completion.
struct PlanDetailView: View {
    @ObservedObject var vm: PlanViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dwell = DwellVerifier()
    @State private var verifyingStopId: Int?
    @State private var photoStop: PlanStop?
    @State private var photoStatus: String?
    @State private var myRating: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if let plan = vm.plan {
                    planBody(plan)
                } else {
                    // Rerolled into a dead zone — nothing to show; close.
                    VStack(spacing: 10) {
                        Text(vm.deadZoneReason ?? "No plan right now.")
                            .font(.nostiaBody(14))
                            .foregroundColor(Color.nostiaTextSecond)
                        Button("Close") { dismiss() }
                            .font(.nostiaBody(15, weight: .semibold))
                            .foregroundColor(Color.nostiaAccent)
                    }
                    .padding(24)
                }
            }
            .background(Color.nostiaBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $photoStop) { stop in
            CameraCaptureView(
                promptText: "At \(stop.name) — grab the moment",
                onCapture: { data in
                    let target = stop
                    photoStop = nil
                    Task { await attachPhoto(data, stop: target) }
                },
                onCancel: { photoStop = nil }
            )
        }
        .onChange(of: dwell.phase) { _, phase in
            if case .confirmed = phase {
                // Refresh stop states (checkmarks, counts) from the server,
                // then retire the inline dwell row — the checkmark takes over.
                Task {
                    await vm.loadCurrent()
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    verifyingStopId = nil
                    dwell.cancel()
                }
            }
        }
    }

    private func planBody(_ plan: AdventurePlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.title)
                        .font(.nostiaDisplay(24, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(plan.description)
                        .font(.nostiaBody(14))
                        .foregroundColor(Color.nostiaTextSecond)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(plan.stops.count) stops · about \(durationLabel(plan.totalMinutes)) · \(AdventureFormat.distance(plan.totalWalkMeters)) on foot")
                        .font(.nostiaBody(13, weight: .semibold))
                        .foregroundColor(Color.nostiaTextMuted)
                }

                timeline(plan)

                if let status = photoStatus {
                    Text(status)
                        .font(.nostiaBody(13))
                        .foregroundColor(Color.nostiaTextSecond)
                }

                if plan.stops.contains(where: { $0.completedByMe == true }) {
                    ratingCard(plan)
                }

                if plan.isGenerated {
                    actions(plan)
                }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Timeline

    private func timeline(_ plan: AdventurePlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plan.stops) { stop in
                if stop.ord > 1 || stop.legWalkMinutes > 1 {
                    legRow(stop)
                }
                stopRow(stop, plan: plan)
                if verifyingStopId == stop.id {
                    dwellRow(stop)
                }
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private func legRow(_ stop: PlanStop) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.nostiaBody(11, weight: .semibold))
                .foregroundColor(Color.nostiaTextMuted)
                .frame(width: 30)
            Text("\(stop.legWalkMinutes) min walk · \(AdventureFormat.distance(stop.legMeters))")
                .font(.nostiaBody(12, weight: .semibold))
                .foregroundColor(Color.nostiaTextMuted)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func stopRow(_ stop: PlanStop, plan: AdventurePlan) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: stop.symbolName)
                .font(.nostiaBody(15, weight: .bold))
                .foregroundColor(Color.nostiaAccent)
                .frame(width: 30, height: 30)
                .background(Color.nostiaAccentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.nostiaBody(16, weight: .bold))
                    .foregroundColor(Color.nostiaTextPrimary)
                HStack(spacing: 6) {
                    if let arrival = stop.arrivalDate {
                        Text(arrival.formatted(date: .omitted, time: .shortened))
                            .font(.nostiaBody(12, weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
                    }
                    Text("· stay ~\(stop.dwellMinutes) min")
                        .font(.nostiaBody(12))
                        .foregroundColor(Color.nostiaTextMuted)
                }
                if let n = stop.completions, n > 1 {
                    Text("\(n) of you checked in here")
                        .font(.nostiaBody(11, weight: .semibold))
                        .foregroundColor(Color.nostiaSuccess)
                }
            }
            Spacer()
            verifyAffordance(stop, plan: plan)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Verification (§6)

    @ViewBuilder
    private func verifyAffordance(_ stop: PlanStop, plan: AdventurePlan) -> some View {
        if stop.completedByMe == true {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    photoStop = stop
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.nostiaBody(13, weight: .bold))
                        .foregroundColor(Color.nostiaAccent)
                        .frame(width: 32, height: 32)
                        .background(Color.nostiaAccentSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.nostiaTap)
                .accessibilityLabel("Add a photo at \(stop.name)")

                Image(systemName: "checkmark.seal.fill")
                    .font(.nostiaBody(20, weight: .bold))
                    .foregroundColor(Color.nostiaSuccess)
                    .accessibilityLabel("Verified")
            }
        } else if plan.isLive && verifyingStopId != stop.id {
            Button {
                Haptics.tap()
                verifyingStopId = stop.id
                dwell.cancel()
                dwell.start(planId: plan.id, stopId: stop.id)
            } label: {
                Text("I'm here")
                    .font(.nostiaBody(13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.nostiaAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.nostiaTap)
            .disabled(dwell.isRunning)
            .accessibilityLabel("Verify you're at \(stop.name)")
        }
    }

    @ViewBuilder
    private func dwellRow(_ stop: PlanStop) -> some View {
        HStack(spacing: 10) {
            switch dwell.phase {
            case .sampling(let remaining):
                ProgressView()
                Text("Hang out here — verifying (\(remaining)s)")
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaTextSecond)
                Spacer()
                Button("Cancel") {
                    dwell.cancel()
                    verifyingStopId = nil
                }
                .font(.nostiaBody(13, weight: .semibold))
                .foregroundColor(Color.nostiaTextMuted)
            case .submitting:
                ProgressView()
                Text("Confirming…")
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaTextSecond)
                Spacer()
            case .confirmed(let corroborated):
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Color.nostiaSuccess)
                Text(corroborated ? "Verified — together, no less" : "Verified")
                    .font(.nostiaBody(13, weight: .semibold))
                    .foregroundColor(Color.nostiaSuccess)
                Spacer()
            case .rejected(let reason), .failed(message: let reason):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(Color.nostiaWarning)
                Text(reason)
                    .font(.nostiaBody(12))
                    .foregroundColor(Color.nostiaTextSecond)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Retry") {
                    if let plan = vm.plan {
                        dwell.start(planId: plan.id, stopId: stop.id)
                    }
                }
                .font(.nostiaBody(13, weight: .bold))
                .foregroundColor(Color.nostiaAccent)
            case .idle:
                EmptyView()
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 40)
    }

    private func attachPhoto(_ jpeg: Data, stop: PlanStop) async {
        guard let plan = vm.plan else { return }
        photoStatus = "Uploading photo…"
        do {
            let token = try await PlansAPI.shared.captureToken(planId: plan.id, stopId: stop.id)
            let resp = try await PlansAPI.shared.uploadStopPhoto(
                planId: plan.id, stopId: stop.id, jpeg: jpeg, nonce: token.nonce
            )
            photoStatus = resp.attached ? "Photo added to \(stop.name)." : "Photo couldn't be used."
        } catch let APIError.httpError(_, message) {
            photoStatus = message
        } catch {
            photoStatus = "Photo upload failed. Try again."
        }
    }

    // MARK: - Rating (§6: one tap, only after a confirmed completion)

    private func ratingCard(_ plan: AdventurePlan) -> some View {
        HStack(spacing: 10) {
            Text("How was it?")
                .font(.nostiaBody(14, weight: .semibold))
                .foregroundColor(Color.nostiaTextPrimary)
            Spacer()
            ForEach(1...5, id: \.self) { star in
                Button {
                    Haptics.select()
                    myRating = star
                    Task { try? await PlansAPI.shared.rate(planId: plan.id, rating: star) }
                } label: {
                    Image(systemName: star <= myRating ? "star.fill" : "star")
                        .font(.nostiaBody(18, weight: .semibold))
                        .foregroundColor(Color.nostiaStar)
                }
                .buttonStyle(.nostiaTap)
                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
        }
        .padding(14)
        .nostiaCard(cornerRadius: 16)
    }

    // MARK: - Actions

    private func actions(_ plan: AdventurePlan) -> some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                Task { await vm.accept() }
            } label: {
                Text("Lock it in")
                    .font(.nostiaDisplay(17, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.nostiaAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.nostiaTap)
            .accessibilityLabel("Keep this plan")

            Button {
                Haptics.tap()
                Task { await vm.reroll() }
            } label: {
                HStack(spacing: 6) {
                    if vm.isWorking {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.nostiaBody(14, weight: .bold))
                    }
                    Text("Reroll")
                        .font(.nostiaBody(15, weight: .semibold))
                }
                .foregroundColor(Color.nostiaAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.nostiaButton)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.nostiaTap)
            .disabled(vm.isWorking)
            .accessibilityLabel("Reroll for a different plan")
        }
    }

    private func durationLabel(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
