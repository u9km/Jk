import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HookMonitorViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("System Status")) {
                    HStack {
                        Text("State")
                        Spacer()
                        Text(stateText)
                            .foregroundColor(stateColor)
                    }
                    HStack {
                        Text("Screenshot Hook")
                        Spacer()
                        Image(systemName: viewModel.statistics?.screenshot_hook_active == 1 ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(viewModel.statistics?.screenshot_hook_active == 1 ? .green : .red)
                    }
                }
                
                Section(header: Text("Interception Statistics")) {
                    StatRow(label: "dlsym calls", value: viewModel.statistics?.total_dlsym_calls ?? 0)
                    StatRow(label: "dlsym blocked", value: viewModel.statistics?.total_dlsym_blocked ?? 0)
                    StatRow(label: "dlopen calls", value: viewModel.statistics?.total_dlopen_calls ?? 0)
                    StatRow(label: "dlopen blocked", value: viewModel.statistics?.total_dlopen_blocked ?? 0)
                    StatRow(label: "sysctl calls", value: viewModel.statistics?.total_sysctl_calls ?? 0)
                    StatRow(label: "sysctl blocked", value: viewModel.statistics?.total_sysctl_blocked ?? 0)
                    StatRow(label: "sysctlbyname calls", value: viewModel.statistics?.total_sysctlbyname_calls ?? 0)
                    StatRow(label: "sysctlbyname blocked", value: viewModel.statistics?.total_sysctlbyname_blocked ?? 0)
                    StatRow(label: "ptrace calls", value: viewModel.statistics?.total_ptrace_calls ?? 0)
                    StatRow(label: "ptrace handled", value: viewModel.statistics?.total_ptrace_handled ?? 0)
                }
                
                Section {
                    Button(action: viewModel.enableSystem) {
                        Label("Enable System", systemImage: "play.circle")
                    }
                    .disabled(viewModel.systemEnabled)
                    
                    Button(action: viewModel.disableSystem) {
                        Label("Disable System", systemImage: "pause.circle")
                    }
                    .disabled(!viewModel.systemEnabled)
                    
                    Button(action: viewModel.restoreSystem) {
                        Label("Restore Original", systemImage: "arrow.uturn.backward.circle")
                    }
                }
            }
            .navigationTitle("Hook Monitor")
            .onAppear {
                viewModel.refreshStatistics()
            }
        }
    }
    
    var stateText: String {
        guard let state = viewModel.statistics?.hook_state else { return "Unknown" }
        switch state {
        case 0: return "Uninitialized"
        case 1: return "Installed"
        case 2: return "Enabled"
        case 3: return "Disabled"
        case 4: return "Restored"
        default: return "Unknown"
        }
    }
    
    var stateColor: Color {
        guard let state = viewModel.statistics?.hook_state else { return .gray }
        switch state {
        case 2: return .green
        case 1: return .orange
        case 0, 3, 4: return .red
        default: return .gray
        }
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .font(.system(.body, design: .monospaced))
        }
    }
}
