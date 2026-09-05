import SwiftUI

@main
struct YumeguriApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(YuTheme.pine)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }
}
