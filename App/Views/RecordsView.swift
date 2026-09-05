import SwiftUI

struct RecordsView: View {
    @Environment(AppStore.self) private var store
    let status: VisitStatus
    let openSpot: (OnsenSpot) -> Void
    let explore: () -> Void
    @State private var query = ""
    @State private var ratingFilter: OnsenRating?
    @State private var sortByName = false

    private var saved: [OnsenRecord] { store.records.filter { $0.status == status } }
    private var filtered: [OnsenRecord] {
        saved.filter {
            (query.isEmpty || $0.spot.name.localizedCaseInsensitiveContains(query) || $0.spot.address.localizedCaseInsensitiveContains(query) || $0.memo.localizedCaseInsensitiveContains(query))
            && (ratingFilter == nil || $0.rating == ratingFilter)
        }.sorted { sortByName ? $0.spot.name.localizedStandardCompare($1.spot.name) == .orderedAscending : $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(status == .visited ? "MY ONSEN JOURNAL" : "MY ONSEN WISHLIST")
                        .font(.system(size: 10, design: .monospaced)).tracking(2).foregroundStyle(YuTheme.gold)
                    Text(status == .visited ? "湯の記憶。" : "いつか、あの湯へ。")
                        .font(.system(size: 32, weight: .medium, design: .serif)).tracking(1).foregroundStyle(YuTheme.ink)
                    Text(status == .visited ? "あたたかな思い出を、一湯ずつ。" : "次の旅が、少し楽しみになる。")
                        .font(.subheadline).foregroundStyle(YuTheme.muted)
                }
                summary
                if saved.isEmpty { emptyState }
                else {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(YuTheme.muted)
                        TextField("名前・エリア・メモで絞り込む", text: $query).font(.subheadline)
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("絞り込みを解除")
                        }
                    }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 17))
                    if status == .visited { ratingChips }
                    HStack {
                        Text("\(filtered.count)件の温泉").font(.subheadline.weight(.semibold)).foregroundStyle(YuTheme.ink)
                        Spacer()
                        Menu {
                            Button("更新が新しい順", systemImage: sortByName ? "clock" : "checkmark") { sortByName = false }
                            Button("名前順", systemImage: sortByName ? "checkmark" : "textformat.abc") { sortByName = true }
                        } label: { Label(sortByName ? "名前順" : "更新順", systemImage: "arrow.up.arrow.down").font(.caption).foregroundStyle(YuTheme.muted) }
                    }
                    VStack(spacing: 12) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, record in
                            Button { openSpot(record.spot) } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    SpotRow(spot: record.spot, record: record, index: index)
                                    if let date = record.visitedOn, status == .visited {
                                        Text(date, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(YuTheme.muted).padding(.horizontal, 18).padding(.bottom, 14)
                                    }
                                    if !record.memo.isEmpty {
                                        Text(record.memo).font(.caption).foregroundStyle(YuTheme.muted).lineLimit(2).padding(.horizontal, 18).padding(.bottom, 14)
                                    }
                                }.background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
                            }.buttonStyle(.plain).accessibilityIdentifier(index == 0 ? "records.firstSpot" : "record.\(record.id)")
                        }
                        if filtered.isEmpty {
                            Text("条件に合う記録がありません。\n検索語や評価の絞り込みを変えてみてください。")
                                .font(.subheadline).foregroundStyle(YuTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 30)
                        }
                    }
                }
            }.padding(24)
        }.scrollDismissesKeyboard(.interactively)
            .id(status)
    }

    private var summary: some View {
        HStack(spacing: 20) {
            OnsenEmblem(size: 62, filled: true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(saved.count)").font(.system(size: 36, weight: .regular, design: .serif))
                    Text(status == .visited ? "湯をめぐりました" : "湯に行きたい").font(.subheadline)
                }.foregroundStyle(YuTheme.pine)
                Text(status == .visited ? "良いと感じた温泉  \(saved.filter { $0.rating == .good }.count)湯" : "気になる温泉を、あなただけのリストに。")
                    .font(.system(size: 11)).foregroundStyle(YuTheme.muted)
            }
            Spacer(minLength: 0)
        }.padding(21).background(YuTheme.sage.opacity(0.65), in: RoundedRectangle(cornerRadius: 24))
    }

    private var emptyState: some View {
        VStack(spacing: 17) {
            Image(systemName: status == .visited ? "book.closed" : "bookmark").font(.system(size: 37, weight: .ultraLight)).foregroundStyle(YuTheme.pine).padding(.top, 20)
            Text(status == .visited ? "はじめの一湯を、残そう。" : "旅の楽しみを、集めよう。")
                .font(.system(.title3, design: .serif)).foregroundStyle(YuTheme.ink)
            Text(status == .visited ? "温泉の詳細で「行った」を選ぶと、\n評価や訪問日、メモを記録できます。" : "地図で気になる温泉を見つけて、\n「行きたい」に保存してみましょう。")
                .font(.subheadline).multilineTextAlignment(.center).lineSpacing(5).foregroundStyle(YuTheme.muted)
            Button(action: explore) { Label("温泉を見つける", systemImage: "map") }.buttonStyle(PrimaryButtonStyle()).padding(.top, 9)
        }.frame(maxWidth: .infinity).padding(24).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 24))
    }

    private var ratingChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("すべて", rating: nil)
                ForEach([OnsenRating.good, .average, .bad]) { rating in filterChip(rating.title, rating: rating) }
            }
        }
    }

    private func filterChip(_ title: String, rating: OnsenRating?) -> some View {
        Button { ratingFilter = rating } label: {
            Text(title).font(.system(size: 13, weight: .medium)).padding(.horizontal, 18).padding(.vertical, 10)
                .foregroundStyle(ratingFilter == rating ? .white : YuTheme.pine)
                .background(ratingFilter == rating ? YuTheme.pine : .white, in: Capsule())
        }.accessibilityAddTraits(ratingFilter == rating ? .isSelected : [])
    }
}
