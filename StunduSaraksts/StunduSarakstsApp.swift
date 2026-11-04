import SwiftUI

@main
struct StunduSarakstsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .backgroundTask(.appRefresh(ChangeNotifier.taskID)) {
            ChangeNotifier.scheduleBackgroundRefresh()
            await ChangeNotifier.check()
        }
    }
}
