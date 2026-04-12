import ServiceManagement
import Foundation

struct LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MacMistress: Failed to toggle launch at login — \(error.localizedDescription)")
        }
    }
}
