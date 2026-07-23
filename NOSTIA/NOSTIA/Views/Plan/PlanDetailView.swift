import SwiftUI

/// The plan artifact (Product Definition v2 §4.5): named, sequenced, timed —
/// stops with walking legs, not search results. Keep / reroll live on the same
/// screen so rejecting a plan costs one tap.
struct PlanDetailView: View {
    @ObservedObject var vm: PlanViewModel
    @Environment(\.dismiss) private var dismiss

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
                stopRow(stop)
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

    private func stopRow(_ stop: PlanStop) -> some View {
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
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
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
