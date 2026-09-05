import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class PhotoEditor {
    var photoIDs: [String] = []
    private(set) var isImporting = false
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    var errorMessage: String?
    @ObservationIgnored private var importTask: Task<Void, Never>?
    @ObservationIgnored private var requestID: UUID?

    func importPhotos(_ items: [PhotosPickerItem], into store: AppStore) {
        guard !isImporting, !store.isReadOnly else { return }
        let remaining = PhotoRepository.maxPhotosPerRecord - photoIDs.count
        let batch = Array(items.prefix(max(remaining, 0)))
        guard !batch.isEmpty else { return }
        let token = UUID()
        requestID = token
        errorMessage = nil
        completedCount = 0
        totalCount = batch.count
        isImporting = true
        importTask = Task { [weak self] in
            guard let self else { return }
            var failureCount = 0
            var firstFailure: String?
            defer {
                if self.requestID == token {
                    self.isImporting = false
                    self.importTask = nil
                    self.requestID = nil
                    if let firstFailure {
                        self.errorMessage = "\(failureCount)枚の写真を追加できませんでした。\n\(firstFailure)"
                    }
                }
            }
            // Load and reduce one photograph at a time, including iCloud downloads.
            for item in batch {
                guard !Task.isCancelled, self.requestID == token else { return }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoImageProcessor.ProcessingError.invalidImage
                    }
                    try Task.checkCancellation()
                    let jpeg = try await Task.detached(priority: .userInitiated) {
                        try PhotoImageProcessor.jpegData(from: data)
                    }.value
                    try Task.checkCancellation()
                    guard self.requestID == token else { return }
                    let id = try store.stagePhoto(jpeg)
                    self.photoIDs.append(id)
                } catch {
                    guard !Task.isCancelled, self.requestID == token else { return }
                    failureCount += 1
                    if firstFailure == nil { firstFailure = error.localizedDescription }
                }
                self.completedCount += 1
            }
        }
    }

    func cancelImport() {
        requestID = nil
        importTask?.cancel()
        importTask = nil
        isImporting = false
    }
}
