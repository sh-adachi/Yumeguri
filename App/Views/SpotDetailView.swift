import SwiftUI
import MapKit

struct SpotDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let spot: OnsenSpot
    @State private var status = VisitStatus.wantToGo
    @State private var rating: OnsenRating?
    @State private var visitedOn = Date()
    @State private var memo = ""
    @State private var confirmingDelete = false
    @State private var confirmingDiscard = false
    @State private var initialSnapshot = ""
    @State private var photoEditor = PhotoEditor()
    @FocusState private var memoFocused: Bool

    private var snapshot: String { "\(status.rawValue)|\(rating?.rawValue ?? "")|\(visitedOn.timeIntervalSince1970)|\(memo)|\(photoEditor.photoIDs.joined(separator: ","))" }
    private var hasChanges: Bool { photoEditor.isImporting || (!initialSnapshot.isEmpty && snapshot != initialSnapshot) }
    private var coordinate: CLLocationCoordinate2D { .init(latitude: spot.latitude, longitude: spot.longitude) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    placeHeader
                    VStack(alignment: .leading, spacing: 13) {
                        fieldLabel("旅のステータス", subtitle: "今の気持ちを記録")
                        HStack(spacing: 10) {
                            statusButton(.wantToGo, symbol: "bookmark")
                            statusButton(.visited, symbol: "checkmark.circle")
                        }
                    }
                    if status == .visited {
                        VStack(alignment: .leading, spacing: 13) {
                            fieldLabel("この温泉、どうだった？", subtitle: "あなたの評価")
                            HStack(spacing: 10) {
                                ratingButton(.good, symbol: "hand.thumbsup")
                                ratingButton(.average, symbol: "minus.circle")
                                ratingButton(.bad, symbol: "hand.thumbsdown")
                            }
                            if rating != nil {
                                Button("評価を未選択に戻す") { rating = nil }.font(.caption).foregroundStyle(YuTheme.muted)
                            }
                        }
                        HStack {
                            Label("訪問日", systemImage: "calendar").font(.subheadline.weight(.medium)).foregroundStyle(YuTheme.ink)
                            Spacer()
                            DatePicker("訪問日", selection: $visitedOn, in: ...Date(), displayedComponents: .date)
                                .labelsHidden().accessibilityIdentifier("detail.visitedOn")
                        }.padding(17).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("ひとことメモ", subtitle: "任意")
                        ZStack(alignment: .topLeading) {
                            if memo.isEmpty {
                                Text(status == .visited ? "お湯の心地よさ、景色、また来たい理由…" : "気になるお湯、旅の予定、持っていくもの…")
                                    .font(.subheadline).foregroundStyle(YuTheme.muted.opacity(0.8)).padding(.horizontal, 15).padding(.top, 19).allowsHitTesting(false)
                            }
                            TextEditor(text: $memo).font(.subheadline).scrollContentBackground(.hidden)
                                .frame(minHeight: 120).padding(10).focused($memoFocused)
                                .accessibilityLabel("ひとことメモ").accessibilityIdentifier("detail.memo")
                        }.background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                    PhotoAttachmentSection(editor: photoEditor)
                    if store.isReadOnly {
                        Text("記録の読み込みに問題があるため、保存を停止しています。アプリを再起動してお試しください。")
                            .font(.subheadline).foregroundStyle(YuTheme.clay)
                    }
                    Button(action: save) { Label("この内容で保存", systemImage: "checkmark") }
                        .buttonStyle(PrimaryButtonStyle()).disabled(store.isReadOnly || photoEditor.isImporting).accessibilityIdentifier("detail.saveBottom")
                    Text("記録と評価は、あなただけの温泉手帖に保存されます。")
                        .font(.system(size: 11)).foregroundStyle(YuTheme.muted).frame(maxWidth: .infinity)
                    if store.record(for: spot) != nil {
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Label("この記録を削除", systemImage: "trash").font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }.tint(YuTheme.clay).disabled(store.isReadOnly || photoEditor.isImporting).accessibilityIdentifier("detail.delete")
                    }
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively).background(YuTheme.paper)
            .navigationTitle("温泉を記録").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { if hasChanges { confirmingDiscard = true } else { dismiss() } }
                        .foregroundStyle(YuTheme.muted).accessibilityIdentifier("detail.close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).fontWeight(.semibold).disabled(store.isReadOnly || photoEditor.isImporting).accessibilityIdentifier("detail.save")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { memoFocused = false } }
            }
            .confirmationDialog("この温泉の記録を削除しますか？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("記録を削除", role: .destructive) { if store.delete(spot) { dismiss() } }.accessibilityIdentifier("detail.confirmDelete")
                Button("キャンセル", role: .cancel) {}
            } message: { Text("評価・訪問日・メモ・添付した写真も削除されます。写真ライブラリの元の写真は残ります。") }
            .confirmationDialog("変更を保存せずに閉じますか？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("変更を破棄", role: .destructive) { photoEditor.cancelImport(); dismiss() }.accessibilityIdentifier("detail.discardChanges")
                Button("編集を続ける", role: .cancel) {}
            }
            .interactiveDismissDisabled(hasChanges)
            .alert("保存できませんでした", isPresented: Binding(get: { store.persistenceError != nil }, set: { if !$0 { store.persistenceError = nil } })) {
                Button("閉じる", role: .cancel) { store.persistenceError = nil }
            } message: { Text(store.persistenceError ?? "") }
            .onAppear { loadRecord() }
            .onDisappear { photoEditor.cancelImport() }
        }
    }

    private var placeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, span: .init(latitudeDelta: 0.018, longitudeDelta: 0.018))), interactionModes: []) {
                Annotation(spot.name, coordinate: coordinate) { OnsenEmblem(size: 45, filled: true).overlay { RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: 3) } }
            }.mapStyle(.standard(pointsOfInterest: .excludingAll)).frame(height: 140).clipShape(RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 9) {
                Text(spot.name).font(.system(size: 27, weight: .semibold, design: .serif)).foregroundStyle(YuTheme.ink)
                Label(spot.address, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(YuTheme.muted)
            }
            HStack(spacing: 18) {
                Button {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                    item.name = spot.name
                    item.openInMaps()
                } label: { Label("マップで開く", systemImage: "arrow.up.forward.app").font(.caption.weight(.semibold)) }
                if let url = spot.websiteURL, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    Link(destination: url) { Label("Webサイト", systemImage: "globe").font(.caption.weight(.semibold)) }
                }
            }.foregroundStyle(YuTheme.pine)
            Rectangle().fill(YuTheme.line).frame(height: 0.7).padding(.top, 5)
        }
    }

    private func fieldLabel(_ title: String, subtitle: String) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(YuTheme.ink)
            Spacer()
            Text(subtitle).font(.system(size: 10)).foregroundStyle(YuTheme.muted)
        }
    }

    private func statusButton(_ choice: VisitStatus, symbol: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { status = choice }
            if choice == .wantToGo { rating = nil }
        } label: {
            Label(choice.title, systemImage: symbol + (status == choice ? ".fill" : ""))
                .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(status == choice ? .white : YuTheme.pine)
                .background(status == choice ? YuTheme.pine : .white, in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityIdentifier("detail.status.\(choice.rawValue)")
        .accessibilityValue(status == choice ? "選択中" : "未選択")
        .accessibilityAddTraits(status == choice ? .isSelected : [])
    }

    private func ratingButton(_ choice: OnsenRating, symbol: String) -> some View {
        Button { rating = choice } label: {
            VStack(spacing: 9) {
                Image(systemName: symbol + (rating == choice ? ".fill" : "")).font(.system(size: 23, weight: .light))
                Text(choice.title).font(.system(size: 13, weight: .medium))
            }.frame(maxWidth: .infinity).padding(.vertical, 17)
                .foregroundStyle(rating == choice ? YuTheme.pine : YuTheme.muted)
                .background(rating == choice ? YuTheme.sage : .white, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(rating == choice ? YuTheme.pine : .clear, lineWidth: 1.2) }
        }.accessibilityIdentifier("detail.rating.\(choice.rawValue)")
            .accessibilityValue(rating == choice ? "選択中" : "未選択")
            .accessibilityAddTraits(rating == choice ? .isSelected : [])
    }

    private func loadRecord() {
        guard initialSnapshot.isEmpty else { return }
        if let record = store.record(for: spot) {
            status = record.status; rating = record.rating; visitedOn = record.visitedOn ?? Date(); memo = record.memo
            photoEditor.photoIDs = record.photoIDs
        }
        initialSnapshot = snapshot
    }

    private func save() {
        memoFocused = false
        guard !photoEditor.isImporting else { return }
        if store.save(spot: spot, status: status, rating: rating, visitedOn: visitedOn, memo: memo, photoIDs: photoEditor.photoIDs) { dismiss() }
    }
}
