import SwiftUI

struct AnalyticsView: View {
    @StateObject private var vm = AnalyticsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if vm.isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(40)
                } else if !vm.hasAccess {
                    // No access state
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 56)).foregroundColor(Color.nostiaTextMuted)
                        Text("Analytics Dashboard").font(.title2.bold()).foregroundColor(.white)
                        Text("Analytics access is available for admins and subscribers.")
                            .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    // Day range picker
                    Picker("Range", selection: $vm.selectedDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.selectedDays) { _ in Task { await vm.load() } }

                    // Metric cards
                    if let d = vm.dashboard {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCard(label: "Total Users", value: d.totalUsers)
                            MetricCard(label: "Active Users", value: d.activeUsers)
                            MetricCard(label: "Total Trips", value: d.totalTrips)
                            MetricCard(label: "Total Posts", value: d.totalPosts)
                            MetricCard(label: "New Today", value: d.newUsersToday)
                            MetricCard(label: "New This Week", value: d.newUsersThisWeek)
                        }
                    }

                    // Funnel
                    if !vm.funnelSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Funnel").font(.headline).foregroundColor(.white)
                            ForEach(vm.funnelSteps) { step in
                                HStack {
                                    Text(step.step.capitalized).font(.subheadline).foregroundColor(.white)
                                    Spacer()
                                    Text("\(step.count)").font(.subheadline.bold()).foregroundColor(Color.nostiaAccent)
                                    if let pct = step.percentage {
                                        Text(String(format: "%.0f%%", pct))
                                            .font(.caption).foregroundColor(Color.nostiaTextSecond)
                                    }
                                }
                                .padding(12).background(Color.nostiaCard).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.nostriaBorder, lineWidth: 1))
                            }
                        }
                    }

                    // Retention
                    if !vm.retention.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Retention").font(.headline).foregroundColor(.white)
                            ForEach(vm.retention) { row in
                                HStack {
                                    Text(row.period.capitalized).font(.subheadline).foregroundColor(.white)
                                    Spacer()
                                    if let rate = row.rate {
                                        Text(String(format: "%.0f%%", rate * 100))
                                            .font(.subheadline.bold()).foregroundColor(Color.nostiaSuccess)
                                    }
                                }
                                .padding(12).background(Color.nostiaCard).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.nostriaBorder, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.nostiaBackground)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

struct MetricCard: View {
    let label: String
    let value: Int?
    var body: some View {
        VStack(spacing: 8) {
            Text(value.map { "\($0)" } ?? "—")
                .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(Color.nostiaTextSecond)
        }
        .frame(maxWidth: .infinity)
        .padding(16).background(Color.nostiaCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nostriaBorder, lineWidth: 1))
    }
}
