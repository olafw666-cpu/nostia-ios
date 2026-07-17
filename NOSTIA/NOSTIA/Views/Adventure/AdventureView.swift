import SwiftUI

/// Adventure tab. One adventure per rolling 24h, drawn from a pre-generated pool:
/// pick a difficulty, then go and physically do it. Success is measured from the
/// phone's pedometer — hit both the step target and the distance target — and earns
/// points that buy profile themes.
struct AdventureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AdventureViewModel()
    @State private var selectedDifficulty: AdventureDifficulty = .easy
    @State private var showStore = false
    @State private var showDiscardConfirm = false
    @State private var showIntro = !UserDefaults.standard.bool(forKey: AdventureView.introSeenKey)

    static let introSeenKey = "nostia_adventure_intro_seen"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if viewModel.isCrafting {
                    craftingCard
                } else {
                    content
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 110) // clear the floating tab bar
        }
        .background(Color.nostiaBackground.ignoresSafeArea())
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: scenePhase) { _, phase in
            // A backgrounded app misses nothing — the pedometer logs in hardware and
            // the query on .active backfills the whole window — but we still need the
            // hook to re-read it and to flush on the way out.
            viewModel.onScenePhaseChange(phase)
        }
        .sheet(isPresented: $showStore) {
            ThemeStoreView(balance: viewModel.pointsBalance) {
                Task { await viewModel.load() }
            }
            .presentationBackground(Color.nostiaBackground)
        }
        .overlay { if showIntro { introOverlay } }
        .overlay(alignment: .top) {
            if let points = viewModel.celebrationPoints {
                celebrationToast(points)
            }
        }
        .alert("Discard this adventure?", isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) { Task { await viewModel.discard() } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("You can discard within 5 minutes of generating (once per day) and pick again.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            NostiaScreenTitle(title: "Adventure")
            Spacer()
            Button {
                Haptics.tap()
                showStore = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.circle.fill")
                        .font(.nostiaBody(16, weight: .bold))
                        .foregroundColor(Color.nostiaStar)
                    Text("\(viewModel.pointsBalance)")
                        .font(.nostiaDisplay(15, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .nostiaCard(cornerRadius: 14, elevation: .flat)
            }
            .buttonStyle(.nostiaTap)
            .accessibilityLabel("\(viewModel.pointsBalance) points. Opens the theme store")
        }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if viewModel.motionUnavailable || viewModel.motionDenied {
            motionPermissionCard
        }

        if let adventure = viewModel.adventure {
            if adventure.isActive {
                if viewModel.canGenerateNow {
                    // >24h old but never completed: still completable until the user
                    // generates again — offer both.
                    generateSection(title: "New adventure available")
                    adventureCard(adventure, interactive: true)
                } else {
                    adventureCard(adventure, interactive: true)
                }
            } else if viewModel.canGenerateNow {
                generateSection(title: "Ready for today's adventure?")
                adventureCard(adventure, interactive: false)
            } else {
                countdownCard
                adventureCard(adventure, interactive: false)
            }
        } else if viewModel.canGenerateNow {
            generateSection(title: "Generate your first adventure")
        }

        if let error = viewModel.errorMessage {
            Text(error)
                .font(.nostiaBody(13))
                .foregroundColor(Color.nostriaDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Motion permission

    /// The feature cannot work without motion data, so say so plainly rather than
    /// showing a progress bar that will never move.
    private var motionPermissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.nostiaBody(18, weight: .semibold))
                    .foregroundColor(Color.nostriaDanger)
                Text(viewModel.motionUnavailable ? "Step tracking unavailable" : "Motion access is off")
                    .font(.nostiaDisplay(15, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
            }
            Text(viewModel.motionUnavailable
                 ? "This device can't count steps, so adventures can't be tracked here."
                 : "Adventures are measured from your steps and walking distance. Turn on Motion & Fitness for Nostia in Settings to track them.")
                .font(.nostiaBody(13))
                .foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.motionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                Button {
                    Haptics.tap()
                    UIApplication.shared.open(url)
                } label: {
                    Text("Open Settings")
                        .font(.nostiaBody(14, weight: .bold))
                        .foregroundColor(Color.nostiaAccent)
                }
                .buttonStyle(.nostiaTap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .nostiaCard(cornerRadius: 16)
    }

    // MARK: - Generate form

    private func generateSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.nostiaDisplay(19, weight: .heavy))
                .foregroundColor(Color.nostiaTextPrimary)

            VStack(spacing: 10) {
                ForEach(AdventureDifficulty.allCases) { difficulty in
                    difficultyRow(difficulty)
                }
            }

            NostiaPrimaryButton(title: "Generate Adventure", systemImage: "sparkles") {
                Haptics.tap()
                markIntroSeen()
                Task { await viewModel.generate(difficulty: selectedDifficulty) }
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private func difficultyRow(_ difficulty: AdventureDifficulty) -> some View {
        let selected = selectedDifficulty == difficulty
        return Button {
            Haptics.select()
            selectedDifficulty = difficulty
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(difficulty.label)
                        .font(.nostiaBody(15, weight: .bold))
                        .foregroundColor(selected ? .white : Color.nostiaTextPrimary)
                    Text(difficulty.blurb)
                        .font(.nostiaBody(12))
                        .foregroundColor(selected ? .white.opacity(0.85) : Color.nostiaTextSecond)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("+\(difficulty.points) pts")
                    .font(.nostiaDisplay(13, weight: .heavy))
                    .foregroundColor(selected ? .white : Color.nostiaAccent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.nostiaAccent : Color.nostiaCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.nostiaCardStroke, lineWidth: selected ? 0 : 0.75)
            )
        }
        .buttonStyle(.nostiaTap)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Generating state

    /// The reveal hold is 20–30s (see AdventureViewModel.craftHold); a static spinner
    /// that long reads as frozen. Advance the copy every 6s off the VM's existing
    /// 1s clock tick — the last phase sticks until the reveal.
    private static let craftingPhases = [
        "Finding your adventure…",
        "Pacing out the distance…",
        "Setting your step targets…",
        "Balancing the challenge…",
        "Adding the finishing touches…",
    ]

    private var craftingMessage: String {
        guard let start = viewModel.craftingStartedAt else { return Self.craftingPhases[0] }
        let phase = Int(viewModel.now.timeIntervalSince(start) / 6)
        return Self.craftingPhases[max(0, min(phase, Self.craftingPhases.count - 1))]
    }

    private var craftingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.nostiaAccent)
            Text(craftingMessage)
                .font(.nostiaDisplay(17, weight: .heavy))
                .foregroundColor(Color.nostiaTextPrimary)
                .id(craftingMessage)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: craftingMessage)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
        .nostiaWarmCard(cornerRadius: 20)
    }

    // MARK: - Adventure card + targets

    private func adventureCard(_ adventure: DailyAdventure, interactive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(adventure.title)
                        .font(.nostiaDisplay(19, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)
                    HStack(spacing: 8) {
                        chip(adventure.difficulty.capitalized)
                        chip("+\(adventure.points) pts")
                        if adventure.status == "completed" {
                            chip("Completed", tinted: true)
                        } else if adventure.status == "expired" {
                            chip("Expired")
                        }
                    }
                }
                Spacer()
            }

            Text(adventure.description)
                .font(.nostiaBody(14))
                .foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)

            // Pre-rework rows carry no targets — they're history, so there's nothing
            // to draw. Rendering 0/0 bars would be a lie.
            if adventure.isMeasured {
                targetsPanel(adventure)
            }

            if interactive && adventure.isActive && adventure.isMeasured {
                completeButton(adventure)
                if viewModel.canDiscard {
                    Button {
                        showDiscardConfirm = true
                    } label: {
                        Text("Not feeling it? Discard (within 5 min)")
                            .font(.nostiaBody(12))
                            .foregroundColor(Color.nostiaTextMuted)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.nostiaTap)
                }
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private func targetsPanel(_ adventure: DailyAdventure) -> some View {
        VStack(spacing: 14) {
            targetBar(
                icon: "shoeprints.fill",
                label: "Steps",
                current: AdventureFormat.steps(adventure.stepsProgress),
                target: AdventureFormat.steps(adventure.stepsTarget ?? 0),
                fraction: adventure.stepsFraction
            )
            targetBar(
                icon: "ruler.fill",
                label: "Distance",
                current: AdventureFormat.distance(adventure.distanceProgressM),
                target: AdventureFormat.distance(adventure.distanceTargetM ?? 0),
                fraction: adventure.distanceFraction
            )
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.nostiaCard))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.nostiaCardStroke, lineWidth: 0.75)
        )
    }

    private func targetBar(icon: String, label: String, current: String, target: String, fraction: Double) -> some View {
        let done = fraction >= 1
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .font(.nostiaBody(14, weight: .semibold))
                    .foregroundColor(done ? Color.nostiaSuccess : Color.nostiaTextMuted)
                Text(label)
                    .font(.nostiaBody(13, weight: .semibold))
                    .foregroundColor(Color.nostiaTextSecond)
                Spacer()
                Text("\(current) / \(target)")
                    .font(.nostiaBody(13, weight: .bold))
                    .foregroundColor(done ? Color.nostiaSuccess : Color.nostiaTextPrimary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.nostiaDivider)
                    Capsule()
                        .fill(done ? Color.nostiaSuccess : Color.nostiaAccent)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
            .animation(.easeOut(duration: 0.3), value: fraction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(current) of \(target)\(done ? ", complete" : "")")
    }

    private func completeButton(_ adventure: DailyAdventure) -> some View {
        let ready = adventure.targetsMet
        return Button {
            guard ready else { return }
            Haptics.tap()
            Task { await viewModel.complete() }
        } label: {
            HStack(spacing: 6) {
                if viewModel.isSyncing {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "flag.checkered")
                        .font(.nostiaBody(17, weight: .semibold))
                }
                Text(ready ? "Complete Adventure  ·  +\(adventure.points) pts" : "Keep going")
                    .font(.nostiaBody(15, weight: .bold))
            }
            .foregroundColor(ready ? .white : Color.nostiaTextMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ready ? Color.nostiaAccent : Color.nostiaDisabled)
            )
        }
        .buttonStyle(.nostiaTap)
        .disabled(!ready)
    }

    // MARK: - Countdown (cooldown state)

    private var countdownCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.nostiaBody(26))
                .foregroundColor(Color.nostiaAccent)
            Text("Next adventure in")
                .font(.nostiaBody(13))
                .foregroundColor(Color.nostiaTextSecond)
            Text(viewModel.countdownText ?? "—")
                .font(.nostiaDisplay(28, weight: .heavy))
                .foregroundColor(Color.nostiaTextPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .nostiaCard(cornerRadius: 20)
    }

    // MARK: - Small bits

    private func chip(_ text: String, tinted: Bool = false) -> some View {
        Text(text)
            .font(.nostiaDisplay(11, weight: .bold))
            .foregroundColor(tinted ? .white : Color.nostiaTextSecond)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tinted ? Color.nostiaSuccess : Color.nostiaButton))
    }

    private func celebrationToast(_ points: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(Color.nostiaStar)
            Text("+\(points) points!")
                .font(.nostiaDisplay(16, weight: .heavy))
                .foregroundColor(Color.nostiaTextPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .nostiaCard(cornerRadius: 16, elevation: .raised)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { viewModel.celebrationPoints = nil }
        }
    }

    // MARK: - First-run explainer

    private var introOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "figure.walk.motion")
                    .font(.nostiaBody(40))
                    .foregroundColor(Color.nostiaAccent)
                Text("Daily Adventures")
                    .font(.nostiaDisplay(22, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                VStack(alignment: .leading, spacing: 12) {
                    introRow(icon: "sparkles", text: "One adventure per day. Tap Generate and you get a real challenge to go and do.")
                    introRow(icon: "shoeprints.fill", text: "Every adventure has a step target and a distance target. Hit both and it's yours.")
                    introRow(icon: "chart.bar.fill", text: "Pick Easy, Medium or Advanced — bigger adventures earn more points (25 / 50 / 100).")
                    introRow(icon: "paintpalette.fill", text: "Spend points on exclusive profile themes in the store.")
                }
                NostiaPrimaryButton(title: "Let's go") {
                    withAnimation { showIntro = false }
                    markIntroSeen()
                }
            }
            .padding(22)
            .nostiaCard(cornerRadius: 24, elevation: .raised)
            .padding(.horizontal, 28)
        }
    }

    private func introRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.nostiaBody(17))
                .foregroundColor(Color.nostiaAccent)
                .frame(width: 24)
            Text(text)
                .font(.nostiaBody(13))
                .foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func markIntroSeen() {
        showIntro = false
        UserDefaults.standard.set(true, forKey: AdventureView.introSeenKey)
    }
}
