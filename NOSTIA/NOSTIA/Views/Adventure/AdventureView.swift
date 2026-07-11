import SwiftUI

/// Adventure tab (replaces Explore — Adventure Page spec §1). One AI-generated
/// adventure per rolling 24h: pick a difficulty, optionally steer it with a
/// prompt, check off steps, earn points, spend them on profile themes.
struct AdventureView: View {
    @StateObject private var viewModel = AdventureViewModel()
    @State private var selectedDifficulty: AdventureDifficulty = .easy
    @State private var prompt = ""
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
        .scrollDismissesKeyboard(.interactively)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.nostiaStar)
                    Text("\(viewModel.pointsBalance)")
                        .font(.nostiaDisplay(15, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .nostiaCard(cornerRadius: 14, elevation: .flat)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(viewModel.pointsBalance) points. Opens the theme store")
        }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if let adventure = viewModel.adventure {
            if adventure.isActive {
                if viewModel.canGenerateNow {
                    // >24h old but never completed: still completable until the
                    // user generates again (§6) — offer both.
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

    // MARK: - Generate form (§12.1)

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

            VStack(alignment: .leading, spacing: 6) {
                TextField("Steer it with a theme (optional)", text: $prompt, axis: .vertical)
                    .font(.nostiaBody(15))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .lineLimit(2...4)
                    .padding(14)
                    .nostiaCard(cornerRadius: 14, elevation: .flat)
                    .onChange(of: prompt) {
                        if prompt.count > 280 { prompt = String(prompt.prefix(280)) }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { hideKeyboard() }
                        }
                    }
                HStack {
                    if let promptError = viewModel.promptError {
                        Text(promptError)
                            .font(.nostiaBody(12))
                            .foregroundColor(Color.nostriaDanger)
                    }
                    Spacer()
                    Text("\(prompt.count)/280")
                        .font(.nostiaBody(11))
                        .foregroundColor(Color.nostiaTextMuted)
                }
            }

            NostiaPrimaryButton(title: "Generate Adventure", systemImage: "sparkles") {
                Haptics.tap()
                hideKeyboard()
                markIntroSeen()
                Task { await viewModel.generate(difficulty: selectedDifficulty, prompt: prompt) }
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(selected ? .white : Color.nostiaTextPrimary)
                    Text(difficulty.blurb)
                        .font(.system(size: 12))
                        .foregroundColor(selected ? .white.opacity(0.85) : Color.nostiaTextSecond)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(difficulty.stepCount) steps")
                        .font(.system(size: 12, weight: .semibold))
                    Text("+\(difficulty.points) pts")
                        .font(.nostiaDisplay(13, weight: .heavy))
                }
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Crafting state (§2 client wait UX)

    private var craftingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.nostiaAccent)
            Text("Crafting your adventure…")
                .font(.nostiaDisplay(17, weight: .heavy))
                .foregroundColor(Color.nostiaTextPrimary)
            Text("This can take a minute. We'll also send a notification when it's ready.")
                .font(.nostiaBody(13))
                .foregroundColor(Color.nostiaTextSecond)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
        .nostiaWarmCard(cornerRadius: 20)
    }

    // MARK: - Adventure card + steps

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

            VStack(spacing: 0) {
                ForEach(adventure.steps) { step in
                    stepRow(step, adventure: adventure, interactive: interactive)
                    if step.order != adventure.steps.last?.order {
                        Rectangle()
                            .fill(Color.nostiaDivider)
                            .frame(height: 1)
                            .padding(.leading, 40)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.nostiaCard))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.nostiaCardStroke, lineWidth: 0.75)
            )

            if interactive && adventure.isActive {
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
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private func stepRow(_ step: DailyAdventureStep, adventure: DailyAdventure, interactive: Bool) -> some View {
        Button {
            guard interactive, adventure.isActive, !step.checked else { return }
            viewModel.checkStep(step.order)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: step.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(step.checked ? Color.nostiaSuccess : Color.nostiaTextMuted)
                Text(step.text)
                    .font(.nostiaBody(14))
                    .foregroundColor(step.checked ? Color.nostiaTextSecond : Color.nostiaTextPrimary)
                    .strikethrough(step.checked, color: Color.nostiaTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!interactive || !adventure.isActive || step.checked)
        .accessibilityLabel("Step \(step.order): \(step.text)")
        .accessibilityAddTraits(step.checked ? [.isButton, .isSelected] : .isButton)
    }

    private func completeButton(_ adventure: DailyAdventure) -> some View {
        let ready = adventure.allStepsChecked
        return Button {
            guard ready else { return }
            Haptics.tap()
            Task { await viewModel.complete() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 17, weight: .semibold))
                Text(ready ? "Complete Adventure  ·  +\(adventure.points) pts"
                           : "Check all steps to complete (\(adventure.checkedCount)/\(adventure.stepCount))")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(ready ? .white : Color.nostiaTextMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ready ? Color.nostiaAccent : Color.nostiaDisabled)
            )
        }
        .buttonStyle(.plain)
        .disabled(!ready)
    }

    // MARK: - Countdown (§12.1 cooldown state)

    private var countdownCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 26))
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

    // MARK: - First-run explainer (§1)

    private var introOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(Color.nostiaAccent)
                Text("Daily Adventures")
                    .font(.nostiaDisplay(22, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                VStack(alignment: .leading, spacing: 12) {
                    introRow(icon: "wand.and.stars", text: "One personal adventure per day, crafted for you. Add a theme if you like.")
                    introRow(icon: "chart.bar.fill", text: "Pick Easy, Medium or Advanced — bigger adventures earn more points (25 / 50 / 100).")
                    introRow(icon: "checklist", text: "Check off every step, then complete it to bank the points.")
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
                .font(.system(size: 17))
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
