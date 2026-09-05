import Foundation

/// A small, synchronous store. Call from one serialized owner (the app's main-actor store).
/// Dates use JSONEncoder's default reference-date format, retaining fractional seconds.
public struct RecordRepository: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(url: URL) {
        self.init(fileURL: url)
    }

    public func load() throws -> [OnsenRecord] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            return []
        }
        let records = try JSONDecoder().decode([OnsenRecord].self, from: data)
        try validate(records)
        return records.map { $0.normalized() }
    }

    public func save(_ records: [OnsenRecord]) throws {
        let normalized = records.map { $0.normalized() }
        try validate(normalized)

        // A failed initial read must never turn into an apparently successful empty overwrite.
        // Existing corrupt files remain intact for recovery and the caller receives the error.
        _ = try load()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(normalized)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    private func validate(_ records: [OnsenRecord]) throws {
        var identifiers = Set<String>()
        for record in records {
            guard !record.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RepositoryError.emptyIdentifier
            }
            guard identifiers.insert(record.id).inserted else {
                throw RepositoryError.duplicateIdentifier(record.id)
            }
            guard record.photoIDs.count <= PhotoRepository.maxPhotosPerRecord else {
                throw RepositoryError.tooManyPhotos
            }
            var photoIdentifiers = Set<UUID>()
            for photoID in record.photoIDs {
                guard let identifier = UUID(uuidString: photoID), photoID.count == 36 else {
                    throw RepositoryError.invalidPhotoIdentifier(photoID)
                }
                guard photoIdentifiers.insert(identifier).inserted else {
                    throw RepositoryError.duplicatePhotoIdentifier(photoID)
                }
            }
            guard record.spot.latitude.isFinite,
                  record.spot.longitude.isFinite,
                  (-90...90).contains(record.spot.latitude),
                  (-180...180).contains(record.spot.longitude) else {
                throw RepositoryError.invalidCoordinate(record.spot.name)
            }
        }
    }
}

public enum RepositoryError: Error, LocalizedError, Equatable {
    case emptyIdentifier
    case duplicateIdentifier(String)
    case invalidCoordinate(String)
    case tooManyPhotos
    case invalidPhotoIdentifier(String)
    case duplicatePhotoIdentifier(String)

    public var errorDescription: String? {
        switch self {
        case .emptyIdentifier:
            "温泉の識別情報がありません。"
        case .duplicateIdentifier:
            "同じ温泉の記録が重複しています。"
        case .invalidCoordinate(let name):
            "「\(name)」の位置情報が正しくありません。"
        case .tooManyPhotos:
            "写真は1つの温泉につき\(PhotoRepository.maxPhotosPerRecord)枚まで保存できます。"
        case .invalidPhotoIdentifier:
            "写真の識別情報が正しくありません。"
        case .duplicatePhotoIdentifier:
            "同じ写真が重複しています。"
        }
    }
}
