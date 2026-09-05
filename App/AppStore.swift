import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    private(set) var records: [OnsenRecord] = []
    var persistenceError: String?
    private(set) var isReadOnly = false
    private let repository: RecordRepository

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let directory = URL.applicationSupportDirectory
            .appending(path: arguments.contains("--uitesting") ? "YumeguriUITests" : "Yumeguri", directoryHint: .isDirectory)
        repository = RecordRepository(fileURL: directory.appending(path: "records.json"))
        do {
            if arguments.contains("--uitesting") && arguments.contains("--reset-records") {
                try repository.save([])
            }
            records = try repository.load()
        } catch {
            isReadOnly = true
            persistenceError = "記録を読み込めませんでした。元のデータを守るため、保存を停止しています。アプリを再起動してお試しください。\n\(error.localizedDescription)"
        }
    }

    func record(for spot: OnsenSpot) -> OnsenRecord? {
        records.first { $0.spot.representsSamePlace(as: spot) }
    }

    @discardableResult
    func save(spot: OnsenSpot, status: VisitStatus, rating: OnsenRating?, visitedOn: Date, memo: String) -> Bool {
        guard !isReadOnly else { return false }
        let existing = record(for: spot)
        let record = OnsenRecord(
            spot: existing?.spot ?? spot,
            status: status,
            rating: status == .visited ? rating : nil,
            visitedOn: status == .visited ? visitedOn : nil,
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing?.createdAt ?? Date(), updatedAt: Date()
        )
        var updated = records.filter { $0.id != record.id }
        updated.insert(record, at: 0)
        return commit(updated)
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
            return true
        } catch {
            persistenceError = "保存できませんでした。空き容量を確認して、もう一度お試しください。\n\(error.localizedDescription)"
            return false
        }
    }
}
