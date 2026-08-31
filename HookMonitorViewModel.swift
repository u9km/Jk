import SwiftUI
import Combine

class HookMonitorViewModel: ObservableObject {
    @Published var statistics: HookStatistics?
    @Published var systemEnabled: Bool = false
    
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatistics()
        }
    }
    
    func refreshStatistics() {
        let stats = GetHookStatistics()
        statistics = stats
        systemEnabled = (stats.hook_state == 2) // HookStateEnabled = 2
    }
    
    func enableSystem() {
        _ = EnableHookSystem()
        refreshStatistics()
    }
    
    func disableSystem() {
        _ = DisableHookSystem()
        refreshStatistics()
    }
    
    func restoreSystem() {
        _ = RestoreHookSystem()
        refreshStatistics()
    }
    
    deinit {
        timer?.invalidate()
    }
}
