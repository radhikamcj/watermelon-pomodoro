import Combine
import ServiceManagement

/// Whether Watermelon opens automatically when you log in (System Settings › General › Login Items).
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = LoginItem.currentlyEnabled

    private static var currentlyEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Watermelon: couldn't change login item: \(error.localizedDescription)")
        }
        // macOS sometimes wants the user to approve it in System Settings first.
        if enabled, SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        isEnabled = Self.currentlyEnabled
    }
}
