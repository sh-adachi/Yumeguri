import SwiftUI
import PhotosUI

struct PhotoAttachmentSection: View {
    @Environment(AppStore.self) private var store
    @Bindable var editor: PhotoEditor
    @State private var selection: [PhotosPickerItem] = []
    @State private var preview: PhotoPreviewSelection?

    var body: some View {
        let hasPhotos = !editor.photoIDs.isEmpty
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("湯めぐりの写真").font(.subheadline.weight(.semibold)).foregroundStyle(YuTheme.ink)
                Spacer()
                Text("\(editor.photoIDs.count) / \(PhotoRepository.maxPhotosPerRecord)")
                    .font(.caption.monospacedDigit()).foregroundStyle(YuTheme.muted)
                    .accessibilityIdentifier("detail.photos.count")
            }
            if !editor.photoIDs.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(Array(editor.photoIDs.enumerated()), id: \.element) { index, id in
                        VStack(spacing: 0) {
                            Button { preview = PhotoPreviewSelection(id: id) } label: {
                                StoredPhotoView(photoID: id)
                                    .frame(height: 98).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .disabled(editor.isImporting)
                            .accessibilityLabel("写真\(index + 1)を拡大")
                            .accessibilityIdentifier("detail.photo.\(index)")
                            Button {
                                editor.photoIDs.removeAll { $0 == id }
                            } label: {
                                Label("削除", systemImage: "minus.circle")
                                    .font(.system(size: 11)).foregroundStyle(YuTheme.clay)
                                    .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            }
                            .disabled(store.isReadOnly || editor.isImporting)
                            .accessibilityLabel("写真\(index + 1)を記録から削除")
                            .accessibilityIdentifier("detail.photo.remove.\(index)")
                        }
                    }
                }
            }
            if editor.isImporting {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("写真を読み込み中… \(editor.completedCount) / \(editor.totalCount)").font(.caption)
                        Spacer()
                    }
                    Text("iCloud上の写真は、読み込みに時間がかかる場合があります。")
                        .font(.caption2).foregroundStyle(YuTheme.muted)
                    Button("読み込みを中止") { editor.cancelImport() }.font(.caption.weight(.semibold))
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
            } else if editor.photoIDs.count < PhotoRepository.maxPhotosPerRecord {
                PhotosPicker(selection: $selection,
                             maxSelectionCount: max(1, PhotoRepository.maxPhotosPerRecord - editor.photoIDs.count),
                             selectionBehavior: .ordered,
                             matching: .images,
                             preferredItemEncoding: .current) {
                    VStack(spacing: 9) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 25, weight: .light))
                        Text(hasPhotos ? "写真を追加する" : "旅の思い出を、写真で。")
                            .font(.system(size: 14, weight: .medium))
                        if !hasPhotos {
                            Text("写真ライブラリから選ぶ").font(.system(size: 11)).foregroundStyle(YuTheme.muted)
                        }
                    }
                    .foregroundStyle(YuTheme.pine).frame(maxWidth: .infinity).padding(.vertical, 22)
                    .background(YuTheme.sage.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).stroke(YuTheme.pine.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
                }
                .disabled(store.isReadOnly)
                .accessibilityLabel("写真を追加")
                .accessibilityIdentifier("detail.photos.add")
            }
            if let error = editor.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(YuTheme.clay).fixedSize(horizontal: false, vertical: true)
            }
            Text("写真の追加・削除は「保存」で反映されます。元の写真は残ります。")
                .font(.system(size: 11)).foregroundStyle(YuTheme.muted)
        }
        .onChange(of: selection) { _, items in
            if !items.isEmpty { editor.importPhotos(items, into: store) }
        }
        .onChange(of: editor.isImporting) { _, importing in
            if !importing { selection = [] }
        }
        .fullScreenCover(item: $preview) { selected in
            PhotoPreviewView(photoIDs: editor.photoIDs, selectedID: selected.id)
        }
    }
}

private struct PhotoPreviewSelection: Identifiable {
    let id: String
}

struct StoredPhotoView: View {
    @Environment(AppStore.self) private var store
    let photoID: String
    var fit = false
    var maxPixelSize = 360
    @State private var photo: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
                    .accessibilityIdentifier("storedPhoto.loaded")
            } else {
                ZStack {
                    YuTheme.sage.opacity(0.5)
                    if failed { Image(systemName: "photo").foregroundStyle(YuTheme.muted) }
                    else { ProgressView().tint(YuTheme.pine) }
                }.accessibilityLabel(failed ? "写真を読み込めませんでした" : "写真を読み込み中")
            }
        }
        .task(id: photoID) {
            photo = nil; failed = false
            guard let url = store.photoURL(for: photoID) else { failed = true; return }
            let size = maxPixelSize
            let loaded = await Task.detached(priority: .utility) {
                PhotoImageProcessor.thumbnail(from: url, maxPixelSize: size)
            }.value
            guard !Task.isCancelled else { return }
            photo = loaded; failed = loaded == nil
        }
    }
}

private struct PhotoPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let photoIDs: [String]
    @State private var selection: String

    init(photoIDs: [String], selectedID: String) {
        self.photoIDs = photoIDs
        _selection = State(initialValue: selectedID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\((photoIDs.firstIndex(of: selection) ?? 0) + 1) / \(photoIDs.count)")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.white)
                Spacer()
                Button("閉じる") { dismiss() }.foregroundStyle(.white)
                    .frame(minWidth: 60, minHeight: 44).accessibilityIdentifier("photoPreview.close")
            }.padding(.horizontal, 24).padding(.top, 6)
            TabView(selection: $selection) {
                ForEach(photoIDs, id: \.self) { id in
                    StoredPhotoView(photoID: id, fit: true, maxPixelSize: 1600)
                        .padding(.horizontal, 12).tag(id)
                        .accessibilityLabel("温泉に添付した写真")
                }
            }.tabViewStyle(.page(indexDisplayMode: photoIDs.count > 1 ? .automatic : .never))
        }
        .background(.black).preferredColorScheme(.dark)
    }
}
