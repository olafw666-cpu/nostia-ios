import SwiftUI

/// "Tonight" — the composed-plan surface (Product Definition v2 §4). Lives at
/// the top of the Adventure tab until the IA collapse makes it the home screen.
/// One primary action; vibe refinements are optional chips that default off and
/// can be ignored entirely (§4.4).
struct PlanTonightSection: View {
    @ObservedObject var vm: PlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tonight")
                .font(.nostiaDisplay(22, weight: .heavy))
                .foregroundColor(Color.nostiaTextPrimary)

            if let plan = vm.plan, plan.isLive {
                planSummaryCard(plan)
            } else {
                startCard
            }
        }
        .sheet(isPresented: $vm.showDetail) {
            PlanDetailView(vm: vm)
                .presentationBackground(Color.nostiaBackground)
        }
    }

    // MARK: - Start state

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A real plan from where you're standing — a few stops, short walks, no research.")
                .font(.nostiaBody(14))
                .foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)

            vibeChips

            Button {
                Haptics.tap()
                Task { await vm.startAdventure() }
            } label: {
                HStack {
                    Spacer()
                    if vm.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.nostiaBody(16, weight: .bold))
                        Text("Start an adventure")
                            .font(.nostiaDisplay(17, weight: .heavy))
                    }
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 15)
                .background(Color.nostiaAccent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.nostiaTap)
            .disabled(vm.isWorking)
            .accessibilityLabel("Start an adventure")

            if vm.locationDenied {
                // The one-line copy IS the pitch — permission buys the plan (§4.2).
                Text("Nostia composes the plan from where you are. Allow location in Settings to start.")
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = vm.deadZoneReason {
                Text(reason)
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaTextSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = vm.errorMessage {
                Text(error)
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostriaDanger)
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private var vibeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlanVibe.allCases) { vibe in
                    let selected = vm.selectedVibe == vibe
                    Button {
                        Haptics.select()
                        vm.selectedVibe = selected ? nil : vibe
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: vibe.symbolName)
                                .font(.nostiaBody(12, weight: .semibold))
                            Text(vibe.label)
                                .font(.nostiaBody(13, weight: .semibold))
                        }
                        .foregroundColor(selected ? .white : Color.nostiaTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected ? Color.nostiaAccent : Color.nostiaButton)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.nostiaTap)
                    .accessibilityLabel("\(vibe.label) vibe\(selected ? ", selected" : "")")
                }
            }
        }
    }

    // MARK: - Live plan state

    private func planSummaryCard(_ plan: AdventurePlan) -> some View {
        Button {
            Haptics.tap()
            vm.showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(plan.title)
                        .font(.nostiaDisplay(18, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.nostiaBody(13, weight: .bold))
                        .foregroundColor(Color.nostiaTextMuted)
                }

                Text("\(plan.stops.count) stops · about \(plan.totalMinutes / 60 > 0 ? "\(plan.totalMinutes / 60)h \(plan.totalMinutes % 60)m" : "\(plan.totalMinutes)m") · \(AdventureFormat.distance(plan.totalWalkMeters)) on foot")
                    .font(.nostiaBody(13, weight: .semibold))
                    .foregroundColor(Color.nostiaTextSecond)

                ForEach(plan.stops.prefix(4)) { stop in
                    HStack(spacing: 8) {
                        Image(systemName: stop.symbolName)
                            .font(.nostiaBody(12, weight: .semibold))
                            .foregroundColor(Color.nostiaAccent)
                            .frame(width: 18)
                        Text(stop.name)
                            .font(.nostiaBody(14))
                            .foregroundColor(Color.nostiaTextPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }

                if plan.isGenerated {
                    rerollRow
                }
            }
            .padding(16)
        }
        .buttonStyle(.nostiaTap)
        .nostiaWarmCard(cornerRadius: 20)
        .accessibilityLabel("\(plan.title), \(plan.stops.count) stops. Opens the plan")
    }

    private var rerollRow: some View {
        Button {
            Haptics.tap()
            Task { await vm.reroll() }
        } label: {
            HStack(spacing: 6) {
                if vm.isWorking {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.nostiaBody(13, weight: .bold))
                }
                Text("Not feeling it? Reroll")
                    .font(.nostiaBody(14, weight: .semibold))
            }
            .foregroundColor(Color.nostiaAccent)
        }
        .buttonStyle(.nostiaTap)
        .disabled(vm.isWorking)
        .accessibilityLabel("Reroll for a different plan")
    }
}
