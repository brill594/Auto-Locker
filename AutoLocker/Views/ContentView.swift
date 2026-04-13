import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AutoLockerStore

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $store.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            ZStack(alignment: .top) {
                Group {
                    switch store.selectedSection {
                    case .overview:
                        OverviewView()
                    case .beacons:
                        BeaconsView()
                    case .rules:
                        RulesView()
                    case .network:
                        NetworkRulesView()
                    case .logs:
                        LogView()
                    case .advanced:
                        AdvancedView()
                    }
                }

                if let message = store.saveFeedbackMessage {
                    SaveFeedbackBanner(message: message)
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: store.saveFeedbackMessage)
            .environmentObject(store)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    StatusPill(state: store.status)
                }
                ToolbarItem(placement: .primaryAction) {
                    Toggle("守护", isOn: Binding(
                        get: { store.guardEnabled },
                        set: { store.setGuardEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                }
            }
        }
    }
}

private struct SaveFeedbackBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.green)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.green.opacity(0.2))
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

struct StatusPill: View {
    let state: GuardRuntimeState

    var body: some View {
        Label(state.label, systemImage: state.systemImage)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var tint: Color {
        switch state {
        case .disabled: return .secondary
        case .guarding: return .green
        case .paused: return .orange
        case .unavailable: return .red
        case .prompting: return .yellow
        }
    }
}

struct InfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 20)
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct NumberInputRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var suffix: String = ""
    var fieldWidth: CGFloat = 80

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer(minLength: 16)
            TextField("", value: clampedValue, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: fieldWidth)
            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
            Stepper("", value: clampedValue, in: range, step: step)
                .labelsHidden()
        }
    }

    private var clampedValue: Binding<Int> {
        Binding(
            get: { value },
            set: { newValue in
                value = min(max(range.lowerBound, newValue), range.upperBound)
            }
        )
    }
}

struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

extension Date {
    var autoLockerShortText: String {
        formatted(date: .abbreviated, time: .standard)
    }
}
