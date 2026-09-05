import SwiftUI

enum AppTab: String, CaseIterable {
    case explore, wishlist, visited
    var title: String {
        switch self { case .explore: "見つける"; case .wishlist: "行きたい"; case .visited: "行った" }
    }
    var symbol: String {
        switch self { case .explore: "map"; case .wishlist: "bookmark"; case .visited: "checkmark.seal" }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab = AppTab.explore
    @State private var selectedSpot: OnsenSpot?
    @State private var showingAbout = false

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                OnsenEmblem(size: 34, filled: true)
                Text("ゆめぐり").font(.system(size: 23, weight: .semibold, design: .serif)).tracking(3).foregroundStyle(YuTheme.ink)
                Spacer()
                Button { showingAbout = true } label: {
                    Image(systemName: "info.circle").font(.system(size: 19)).foregroundStyle(YuTheme.muted).frame(width: 44, height: 44)
                }.accessibilityLabel("ゆめぐりについて")
            }
            .padding(.horizontal, 24).padding(.top, 5).padding(.bottom, 12)
            Group {
                switch selectedTab {
                case .explore:
                    ExploreView(openSpot: { selectedSpot = $0 })
                case .wishlist:
                    RecordsView(status: .wantToGo, openSpot: { selectedSpot = $0 }, explore: { selectedTab = .explore })
                case .visited:
                    RecordsView(status: .visited, openSpot: { selectedSpot = $0 }, explore: { selectedTab = .explore })
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(YuTheme.paper)
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .sheet(item: $selectedSpot, onDismiss: { store.finishPhotoEditing() }) { spot in
            SpotDetailView(spot: spot).environment(store)
        }
        .sheet(isPresented: $showingAbout) { aboutView }
        .alert("記録についてのお知らせ", isPresented: Binding(get: { store.persistenceError != nil && selectedSpot == nil }, set: { if !$0 { store.persistenceError = nil } })) {
            Button("閉じる", role: .cancel) { store.persistenceError = nil }
        } message: { Text(store.persistenceError ?? "") }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol + (selectedTab == tab ? ".fill" : ""))
                            .font(.system(size: 21, weight: .medium)).frame(height: 24)
                        Text(tab.title).font(.system(size: 11, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? YuTheme.pine : YuTheme.muted)
                    .frame(maxWidth: .infinity).padding(.top, 13).padding(.bottom, 8)
                    .background(alignment: .top) {
                        if selectedTab == tab { Capsule().fill(YuTheme.pine).frame(width: 28, height: 3) }
                    }
                }
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .background(.white)
        .overlay(alignment: .top) { YuTheme.line.frame(height: 0.5) }
    }

    private var aboutView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OnsenEmblem(size: 70, filled: true)
                    Text("一湯ずつ、\nわたしの旅になる。").font(.system(.largeTitle, design: .serif, weight: .medium)).foregroundStyle(YuTheme.ink)
                    Text("ゆめぐりは、気になる温泉と旅の思い出を残す、あなたの温泉手帖です。")
                    Label("記録はこの端末に保存", systemImage: "iphone")
                    Text("アカウント登録は不要です。端末間の同期機能はありません。アプリを削除すると記録も削除されます。").font(.subheadline).foregroundStyle(YuTheme.muted)
                    Label("写真も温泉の記録と一緒に", systemImage: "photo.on.rectangle")
                    Text("写真ライブラリから選んだ写真を、1つの温泉につき10枚まで端末内に保存できます。アプリ内で写真を削除しても、写真ライブラリの元の写真は残ります。").font(.subheadline).foregroundStyle(YuTheme.muted)
                    Label("地図と検索はAppleのマップを利用", systemImage: "map")
                    Text("検索にはインターネット接続が必要です。検索結果には温泉街、旅館、入浴施設などが含まれます。営業状況は施設の公式情報でご確認ください。現在地は「現在地」ボタンを押したときだけ利用します。").font(.subheadline).foregroundStyle(YuTheme.muted)
                    Text("はじめの温泉候補は代表地点を示すサンプルです。訪問や評価の記録は、すべてあなた自身が追加します。").font(.caption).foregroundStyle(YuTheme.muted)
                    Text("YUMEGURI  /  1.0").font(.caption.monospaced()).tracking(3).foregroundStyle(YuTheme.gold)
                }.padding(28)
            }.background(YuTheme.paper)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { showingAbout = false } } }
        }
    }
}
