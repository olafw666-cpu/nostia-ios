import SwiftUI

/// "Plan" tab inside a vault: a claimable task checklist and a date poll. This is the
/// answer to "wait, who's booking?" — tasks get an owner, dates get votes, and claims
/// and completions are announced in the vault chat by the server.
struct VaultPlanView: View {
    let tripId: Int
    let isKicked: Bool

    @State private var tasks: [TripTask] = []
    @State private var dateOptions: [TripDateOption] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var newTaskTitle = ""
    @State private var showDatePicker = false
    @State private var proposedDate = Date().addingTimeInterval(86_400)
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var me: Int? { AuthManager.shared.currentUserId }
    private var leadingVotes: Int { dateOptions.map(\.votes).max() ?? 0 }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: responsive.spacing(18)) {
                if isLoading && tasks.isEmpty && dateOptions.isEmpty {
                    ProgressView().tint(Color.nostiaAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    tasksSection
                    datesSection
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.nostiaBody(13))
                        .foregroundColor(Color.nostriaDanger)
                }
            }
            .padding(.horizontal, responsive.spacing(16))
            .padding(.top, 6)
            .padding(.bottom, 40)
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showDatePicker) { proposeDateSheet }
    }

    // MARK: - Tasks

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NostiaRowHeader(title: "Tasks", actionTitle: nil)
            Text("Claim a task so everyone knows who's on it.")
                .font(.nostiaBody(13)).foregroundColor(Color.nostiaTextSecond)

            if !isKicked {
                HStack(spacing: 8) {
                    TextField("Add a task (e.g. Book the rooms)", text: $newTaskTitle)
                        .font(.nostiaBody(15))
                        .foregroundColor(Color.nostiaTextPrimary)
                        .submitLabel(.done)
                        .onSubmit { Task { await addTask() } }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .nostiaCard(cornerRadius: 14, elevation: .flat)
                    Button {
                        Haptics.tap()
                        Task { await addTask() }
                    } label: {
                        Image(systemName: "plus")
                            .font(.nostiaBody(18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                                      ? Color.nostiaDisabled : Color.nostiaAccent))
                    }
                    .buttonStyle(.nostiaTap)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add task")
                }
            }

            if tasks.isEmpty && !isLoading {
                EmptyStateView(icon: "checklist", text: "No tasks yet",
                               sub: "Flights, rooms, tickets — split the work")
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        taskRow(task)
                        if task.id != tasks.last?.id {
                            Rectangle().fill(Color.nostiaDivider).frame(height: 1).padding(.leading, 46)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.nostiaCard))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.nostiaCardStroke, lineWidth: 0.75))
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private func taskRow(_ task: TripTask) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Done checkbox
            Button {
                guard !isKicked else { return }
                Haptics.tap()
                Task { await toggleDone(task) }
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.nostiaBody(22))
                    .foregroundColor(task.done ? Color.nostiaSuccess : Color.nostiaTextMuted)
            }
            .buttonStyle(.nostiaTap)
            .disabled(isKicked)
            .accessibilityLabel(task.done ? "Mark \(task.title) not done" : "Mark \(task.title) done")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.nostiaBody(15, weight: .semibold))
                    .foregroundColor(task.done ? Color.nostiaTextSecond : Color.nostiaTextPrimary)
                    .strikethrough(task.done, color: Color.nostiaTextMuted)
                if let claimer = task.claimerName {
                    Text(task.claimedBy == me ? "You're on it" : "\(claimer) is on it")
                        .font(.nostiaBody(12))
                        .foregroundColor(Color.nostiaAccent)
                } else {
                    Text("Unclaimed")
                        .font(.nostiaBody(12))
                        .foregroundColor(Color.nostiaTextMuted)
                }
            }
            Spacer()

            if !isKicked && !task.done {
                if task.claimedBy == nil {
                    Button {
                        Haptics.tap()
                        Task { await toggleClaim(task) }
                    } label: {
                        Text("Claim")
                            .font(.nostiaBody(13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(Color.nostiaAccent))
                    }
                    .buttonStyle(.nostiaTap)
                } else if task.claimedBy == me {
                    Button {
                        Haptics.tap()
                        Task { await toggleClaim(task) }
                    } label: {
                        Text("Release")
                            .font(.nostiaBody(13, weight: .bold))
                            .foregroundColor(Color.nostiaTextSecond)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(Color.nostiaButton))
                            .overlay(Capsule().stroke(Color.nostiaCardStroke, lineWidth: 0.75))
                    }
                    .buttonStyle(.nostiaTap)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .contextMenu {
            if !isKicked {
                Button(role: .destructive) {
                    Task { await deleteTask(task) }
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Date poll

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NostiaRowHeader(title: "When works?", actionTitle: nil)
                if !isKicked {
                    Button {
                        Haptics.tap()
                        showDatePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Propose")
                        }
                        .font(.nostiaBody(13, weight: .bold))
                        .foregroundColor(Color.nostiaAccent)
                    }
                    .buttonStyle(.nostiaTap)
                }
            }
            Text("Propose dates and vote — the group's answer sorts itself out.")
                .font(.nostiaBody(13)).foregroundColor(Color.nostiaTextSecond)

            if dateOptions.isEmpty && !isLoading {
                EmptyStateView(icon: "calendar.badge.plus", text: "No dates proposed",
                               sub: "Propose the first date")
            } else {
                VStack(spacing: 0) {
                    ForEach(dateOptions) { option in
                        dateRow(option)
                        if option.id != dateOptions.last?.id {
                            Rectangle().fill(Color.nostiaDivider).frame(height: 1).padding(.leading, 14)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.nostiaCard))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.nostiaCardStroke, lineWidth: 0.75))
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private func dateRow(_ option: TripDateOption) -> some View {
        let leading = option.votes > 0 && option.votes == leadingVotes
        return Button {
            guard !isKicked else { return }
            Haptics.select()
            Task { await toggleVote(option) }
        } label: {
            HStack(spacing: 12) {
                Text(option.displayDate)
                    .font(.nostiaBody(15, weight: leading ? .bold : .semibold))
                    .foregroundColor(Color.nostiaTextPrimary)
                if leading {
                    Text("Front-runner")
                        .font(.nostiaDisplay(10, weight: .bold))
                        .foregroundColor(Color.nostiaAccent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.nostiaAccentSoft))
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: option.voted ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.nostiaBody(15))
                    Text("\(option.votes)")
                        .font(.nostiaDisplay(14, weight: .heavy))
                        .monospacedDigit()
                }
                .foregroundColor(option.voted ? Color.nostiaAccent : Color.nostiaTextMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.nostiaTap)
        .disabled(isKicked)
        .accessibilityLabel("\(option.displayDate), \(option.votes) votes\(option.voted ? ", you voted" : "")")
        .accessibilityHint(option.voted ? "Removes your vote" : "Votes for this date")
        .contextMenu {
            if !isKicked {
                Button(role: .destructive) {
                    Task { await deleteDate(option) }
                } label: {
                    Label("Remove Date", systemImage: "trash")
                }
            }
        }
    }

    private var proposeDateSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker("Trip date", selection: $proposedDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color.nostiaAccent)
                    .padding(.horizontal, 8)
                NostiaPrimaryButton(title: "Propose This Date", systemImage: "calendar.badge.plus") {
                    Haptics.tap()
                    Task { await proposeDate() }
                }
                .padding(.horizontal, 16)
                Spacer()
            }
            .padding(.top, 10)
            .background(Color.nostiaBackground.ignoresSafeArea())
            .navigationTitle("Propose a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showDatePicker = false }
                        .foregroundColor(Color.nostiaTextSecond)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions

    private func load() async {
        do {
            let plan = try await TripsAPI.shared.getPlan(tripId: tripId)
            tasks = plan.tasks
            dateOptions = plan.dateOptions
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load the plan — pull to retry."
        }
        isLoading = false
    }

    private func addTask() async {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        do {
            let task = try await TripsAPI.shared.addTask(tripId: tripId, title: title)
            tasks.append(task)
            newTaskTitle = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleClaim(_ task: TripTask) async {
        do {
            let updated = try await TripsAPI.shared.toggleTaskClaim(tripId: tripId, taskId: task.id)
            replaceTask(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleDone(_ task: TripTask) async {
        do {
            let updated = try await TripsAPI.shared.toggleTaskDone(tripId: tripId, taskId: task.id)
            replaceTask(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTask(_ task: TripTask) async {
        do {
            try await TripsAPI.shared.deleteTask(tripId: tripId, taskId: task.id)
            tasks.removeAll { $0.id == task.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceTask(_ task: TripTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
        errorMessage = nil
    }

    private func proposeDate() async {
        let wire = DateFormatter()
        wire.dateFormat = "yyyy-MM-dd"
        wire.locale = Locale(identifier: "en_US_POSIX")
        do {
            dateOptions = try await TripsAPI.shared.addDateOption(tripId: tripId, date: wire.string(from: proposedDate))
            showDatePicker = false
            errorMessage = nil
        } catch {
            showDatePicker = false
            errorMessage = error.localizedDescription
        }
    }

    private func toggleVote(_ option: TripDateOption) async {
        do {
            dateOptions = try await TripsAPI.shared.toggleDateVote(tripId: tripId, optionId: option.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteDate(_ option: TripDateOption) async {
        do {
            try await TripsAPI.shared.deleteDateOption(tripId: tripId, optionId: option.id)
            dateOptions.removeAll { $0.id == option.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
