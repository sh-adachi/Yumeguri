import SwiftUI
import MapKit

struct ExploreView: View {
    @Environment(AppStore.self) private var store
    @State private var search = OnsenSearchService()
    @State private var location = LocationService()
    @State private var query = ""
    @State private var hasSearched = false
    @State private var position: MapCameraPosition = .region(Self.initialRegion)
    @State private var visibleRegion = Self.initialRegion
    @State private var searchTask: Task<Void, Never>?
    @State private var lastQuery = "温泉"
    @State private var lastRegion: MKCoordinateRegion?
    @State private var lastFitMap = false
    @FocusState private var searchFocused: Bool
    var openSpot: (OnsenSpot) -> Void

    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.1, longitude: 138.3),
        span: MKCoordinateSpan(latitudeDelta: 4.3, longitudeDelta: 5.0)
    )
    private var spots: [OnsenSpot] { hasSearched ? search.results : OnsenCatalog.spots }
    private var mapSpots: [OnsenSpot] {
        var shown = spots
        for record in store.records where !shown.contains(where: { store.record(for: $0)?.id == record.id }) { shown.append(record.spot) }
        return shown
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introduction
                searchBar
                mapSection
                if let error = location.errorMessage {
                    message(error, symbol: "location.slash")
                }
                resultsSection
                Text("一湯ずつ、わたしの旅になる。")
                    .font(.system(.caption, design: .serif)).tracking(2)
                    .foregroundStyle(YuTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 12)
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: location.coordinate?.latitude) { _, _ in centerOnLocation() }
        .onChange(of: location.coordinate?.longitude) { _, _ in centerOnLocation() }
        .onDisappear { searchTask?.cancel(); search.cancel() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("あなただけの、温泉手帖").font(.system(size: 11, weight: .medium)).tracking(2).foregroundStyle(YuTheme.gold)
                Spacer()
                Text("JAPAN / ONSEN").font(.system(size: 9, design: .monospaced)).tracking(1).foregroundStyle(YuTheme.muted)
            }
            HStack(alignment: .bottom) {
                Text("次の一湯に、\n出会おう。")
                    .font(.system(size: 33, weight: .medium, design: .serif)).tracking(2).lineSpacing(5)
                    .foregroundStyle(YuTheme.ink).fixedSize(horizontal: false, vertical: true)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(store.records.filter { $0.status == .visited }.count)").font(.system(size: 32, weight: .light, design: .serif))
                        Text("湯").font(.caption)
                    }.foregroundStyle(YuTheme.pine)
                    Text("これまでの湯めぐり").font(.system(size: 9)).foregroundStyle(YuTheme.muted)
                }.padding(.bottom, 6)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(YuTheme.pine)
            TextField("温泉名・地名で探す", text: $query)
                .font(.subheadline).submitLabel(.search).autocorrectionDisabled()
                .focused($searchFocused)
                .accessibilityIdentifier("explore.search")
                .onSubmit { performSearch(inCurrentArea: false) }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(YuTheme.muted).frame(width: 44, height: 44) }
                    .accessibilityLabel("検索語を消す")
            }
            Button { performSearch(inCurrentArea: false) } label: {
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 36, height: 36).background(YuTheme.pine, in: Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
            }.accessibilityLabel("温泉を検索").accessibilityIdentifier("explore.submit")
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(YuTheme.line, lineWidth: 0.7) }
    }

    private var mapSection: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                ForEach(mapSpots) { spot in
                    Annotation(spot.name, coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                        Button { openSpot(spot) } label: {
                            VStack(spacing: 0) {
                                OnsenMark().stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round)).foregroundStyle(.white).padding(7)
                                    .frame(width: 38, height: 38)
                                    .background(store.record(for: spot)?.status == .wantToGo ? YuTheme.gold : YuTheme.pine, in: Circle())
                                    .overlay { Circle().stroke(.white, lineWidth: 2.5) }
                                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(YuTheme.pine).offset(y: -3)
                            }.shadow(color: YuTheme.ink.opacity(0.18), radius: 4, y: 2)
                        }.accessibilityLabel("\(spot.name)の詳細")
                    }
                }
                if let coordinate = location.coordinate {
                    Annotation("現在地", coordinate: coordinate) {
                        Circle().fill(.blue).frame(width: 14, height: 14).overlay { Circle().stroke(.white, lineWidth: 3) }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            .onMapCameraChange(frequency: .onEnd) { visibleRegion = $0.region }
            .frame(height: 255)
            .overlay(alignment: .topLeading) {
                Label("湯めぐりマップ", systemImage: "map")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(YuTheme.ink)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule()).padding(12).allowsHitTesting(false)
            }
            HStack(spacing: 12) {
                Button { performSearch(inCurrentArea: true) } label: {
                    HStack(spacing: 6) {
                        if search.isSearching { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                        Text("このエリアの温泉を探す")
                    }.font(.system(size: 12, weight: .semibold)).frame(minHeight: 44).contentShape(Rectangle())
                }.disabled(search.isSearching).accessibilityIdentifier("explore.searchArea")
                Spacer(minLength: 0)
                Button { location.requestLocation() } label: {
                    HStack(spacing: 5) {
                        if location.isLocating { ProgressView().controlSize(.small) }
                        else { Image(systemName: "location") }
                        Text("現在地")
                    }.font(.system(size: 12, weight: .medium)).frame(minWidth: 62, minHeight: 44).contentShape(Rectangle())
                }.disabled(location.isLocating).accessibilityIdentifier("explore.location")
            }.foregroundStyle(YuTheme.pine).padding(.horizontal, 14).padding(.vertical, 5).background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay { RoundedRectangle(cornerRadius: 23).stroke(YuTheme.line, lineWidth: 0.6) }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(title: hasSearched ? "見つけた温泉" : "気になる温泉から", subtitle: hasSearched ? "\(spots.count)件" : "旅のきっかけに")
            if hasSearched {
                Button {
                    searchTask?.cancel(); search.cancel(); hasSearched = false; query = ""
                    withAnimation { position = .region(Self.initialRegion) }
                } label: { Label("はじめの温泉候補に戻る", systemImage: "arrow.uturn.backward").font(.caption) }
            }
            if search.isSearching {
                HStack { ProgressView(); Text("温泉を探しています…").font(.subheadline).foregroundStyle(YuTheme.muted) }
                    .frame(maxWidth: .infinity).padding(30)
            } else if let error = search.errorMessage, hasSearched {
                message(error, symbol: "wifi.exclamationmark")
                Button("もう一度検索する") { runSearch(query: lastQuery, region: lastRegion, fitMap: lastFitMap) }.font(.subheadline.weight(.semibold))
            } else if spots.isEmpty {
                message("温泉が見つかりませんでした。別の地名で検索するか、地図を動かしてエリアを広げてみてください。", symbol: "map")
            } else {
                ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                    Button { openSpot(spot) } label: { SpotRow(spot: spot, record: store.record(for: spot), index: index) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(index == 0 ? (hasSearched ? "search.firstSpot" : "catalog.firstSpot") : "spot.\(spot.id)")
                }
                if !hasSearched {
                    Text("代表地点のサンプルです。周辺の施設は地図検索で探せます。")
                        .font(.system(size: 10)).foregroundStyle(YuTheme.muted).padding(.horizontal, 3)
                }
            }
        }
    }

    private func message(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol).font(.subheadline).foregroundStyle(YuTheme.muted)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    private func performSearch(inCurrentArea: Bool) {
        let region = inCurrentArea || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? visibleRegion : nil
        let term = inCurrentArea ? "温泉" : query
        runSearch(query: term, region: region, fitMap: !inCurrentArea)
    }

    private func runSearch(query: String, region: MKCoordinateRegion?, fitMap: Bool) {
        searchFocused = false
        searchTask?.cancel()
        hasSearched = true
        lastQuery = query; lastRegion = region; lastFitMap = fitMap
        searchTask = Task {
            await search.search(query: query, region: region)
            guard !Task.isCancelled, !search.results.isEmpty else { return }
            if fitMap { withAnimation(.easeInOut(duration: 0.5)) { fitResults() } }
        }
    }

    private func fitResults() {
        let points = search.results.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        var rect = MKMapRect.null
        for point in points { rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1)) }
        guard !rect.isNull else { return }
        let padded = rect.insetBy(dx: -max(rect.width * 0.2, 3000), dy: -max(rect.height * 0.2, 3000))
        position = .rect(padded)
    }

    private func centerOnLocation() {
        guard let coordinate = location.coordinate else { return }
        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12))
        visibleRegion = region
        withAnimation { position = .region(region) }
    }
}
