import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    private(set) var records: [OnsenRecord] = []
    var persistenceError: String?
    private(set) var isReadOnly = false
    private let repository: RecordRepository
    private let photoRepository: PhotoRepository
    private var activeDraftPhotoIDs = Set<String>()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let directory = URL.applicationSupportDirectory
            .appending(path: arguments.contains("--uitesting") ? "YumeguriUITests" : "Yumeguri", directoryHint: .isDirectory)
        repository = RecordRepository(fileURL: directory.appending(path: "records.json"))
        photoRepository = PhotoRepository(directoryURL: directory.appending(path: "Photos", directoryHint: .isDirectory))
        do {
            if arguments.contains("--uitesting") && arguments.contains("--reset-records") {
                try repository.save([])
            }
            records = try repository.load()
            // Only clean up after a successful metadata read. A corrupt record file
            // must never cause its photographs to be treated as unreferenced.
            try? photoRepository.discardAllDrafts()
            cleanUpPhotos()
        } catch {
            isReadOnly = true
            persistenceError = "記録を読み込めませんでした。元のデータを守るため、保存を停止しています。アプリを再起動してお試しください。\n\(error.localizedDescription)"
        }
    }

    func record(for spot: OnsenSpot) -> OnsenRecord? {
        records.first { $0.spot.representsSamePlace(as: spot) }
    }

    @discardableResult
    func save(spot: OnsenSpot, status: VisitStatus, rating: OnsenRating?, visitedOn: Date, memo: String, photoIDs: [String]? = nil) -> Bool {
        guard !isReadOnly else { return false }
        let existing = record(for: spot)
        let record = OnsenRecord(
            spot: existing?.spot ?? spot,
            status: status,
            rating: status == .visited ? rating : nil,
            visitedOn: status == .visited ? visitedOn : nil,
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            photoIDs: photoIDs ?? existing?.photoIDs ?? [],
            createdAt: existing?.createdAt ?? Date(), updatedAt: Date()
        )
        var updated = records.filter { $0.id != record.id }
        updated.insert(record, at: 0)
        do {
            // Make images durable before publishing metadata that refers to them.
            // Drafts are retained if either the image or JSON write fails.
            try photoRepository.commit(record.photoIDs)
        } catch {
            persistenceError = "写真を保存できませんでした。\n\(error.localizedDescription)"
            return false
        }
        return commit(updated)
    }

    func photoURL(for id: String) -> URL? {
        try? photoRepository.fileURL(for: id)
    }

    func stagePhoto(_ data: Data) throws -> String {
        guard !isReadOnly else { throw CocoaError(.fileWriteNoPermission) }
        let id = try photoRepository.stage(data)
        activeDraftPhotoIDs.insert(id)
        return id
    }

    /// Called only when the actual record editor closes, including swipe dismissal.
    /// Presenting a photo preview or the system picker must not discard drafts.
    func finishPhotoEditing() {
        guard !isReadOnly else { return }
        try? photoRepository.discardDrafts(Array(activeDraftPhotoIDs))
        activeDraftPhotoIDs.removeAll()
        cleanUpPhotos()
    }

    private func cleanUpPhotos() {
        let retained = Set(records.flatMap(\.photoIDs)).union(activeDraftPhotoIDs)
        // Failure to remove an orphan should not turn a successful save into an
        // error. Startup retries cleanup; referenced photos are always retained.
        try? photoRepository.removeUnreferenced(keeping: retained)
    }

    @discardableResult
    func delete(_ spot: OnsenSpot) -> Bool {
        guard let record = record(for: spot), !isReadOnly else { return false }
        return commit(records.filter { $0.id != record.id })
    }

    private func commit(_ updated: [OnsenRecord]) -> Bool {
        do {
            try repository.save(updated)
            records = updated
            persistenceError = nil
            cleanUpPhotos()
            return true
        } catch {
            persistenceError = "保存できませんでした。空き容量を確認して、もう一度お試しください。\n\(error.localizedDescription)"
            return false
        }
    }
}
