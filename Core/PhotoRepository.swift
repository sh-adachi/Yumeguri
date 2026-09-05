import Foundation

/// Stores JPEG files separately from record metadata. Use from one serialized owner.
/// New imports remain in Drafts until the record save succeeds or editing is cancelled.
public struct PhotoRepository: Sendable {
    public static let maxPhotosPerRecord = 10
    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    private var draftsURL: URL {
        directoryURL.appendingPathComponent("Drafts", isDirectory: true)
    }

    /// The app supplies resized JPEG bytes; image decoding is deliberately outside Core.
    public func stage(_ data: Data) throws -> String {
        guard !data.isEmpty else { throw PhotoRepositoryError.emptyData }
        try FileManager.default.createDirectory(at: draftsURL, withIntermediateDirectories: true)
        let id = UUID().uuidString
        try data.write(to: photoURL(for: id, in: draftsURL), options: .atomic)
        return id
    }

    public func fileURL(for id: String) throws -> URL {
        try validate(id)
        let savedURL = photoURL(for: id, in: directoryURL)
        if try isRegularFile(savedURL) { return savedURL }
        let draftURL = photoURL(for: id, in: draftsURL)
        if try isRegularFile(draftURL) { return draftURL }
        throw PhotoRepositoryError.missingPhoto(id)
    }

    /// Copies drafts atomically, keeping every source available if this or record saving fails.
    /// Call discardDrafts only after the referring record JSON has been saved successfully.
    public func commit(_ ids: [String]) throws {
        var copies: [(source: URL, destination: URL)] = []
        for id in Set(ids) {
            try validate(id)
            let destination = photoURL(for: id, in: directoryURL)
            if try isRegularFile(destination) { continue }
            let source = photoURL(for: id, in: draftsURL)
            guard try isRegularFile(source) else { throw PhotoRepositoryError.missingPhoto(id) }
            copies.append((source, destination))
        }
        guard !copies.isEmpty else { return }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        for copy in copies {
            let data = try Data(contentsOf: copy.source)
            try data.write(to: copy.destination, options: .atomic)
        }
    }

    /// Cancelling an editor may discard drafts, but must never remove saved photographs.
    public func discardDrafts(_ ids: [String]) throws {
        try ids.forEach(validate)
        for id in Set(ids) {
            let url = photoURL(for: id, in: draftsURL)
            if try isRegularFile(url) { try FileManager.default.removeItem(at: url) }
        }
    }

    /// Remove orphans only after the complete, valid set of saved record IDs is known.
    public func removeUnreferenced(keeping ids: Set<String>) throws {
        try ids.forEach(validate)
        let retained = Set(ids.compactMap(UUID.init(uuidString:)))
        for url in try managedPhotos(in: directoryURL) {
            guard let identifier = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  !retained.contains(identifier) else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Safe at app startup, before any photo editor has an active draft.
    public func discardAllDrafts() throws {
        for url in try managedPhotos(in: draftsURL) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func photoURL(for id: String, in directory: URL) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("jpg")
    }

    private func validate(_ id: String) throws {
        guard id.count == 36, UUID(uuidString: id) != nil else {
            throw PhotoRepositoryError.invalidIdentifier(id)
        }
    }

    private func isRegularFile(_ url: URL) throws -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            return values.isRegularFile == true && values.isSymbolicLink != true
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            return false
        }
    }

    private func managedPhotos(in directory: URL) throws -> [URL] {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            return []
        }
        return try contents.filter { url in
            let id = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension == "jpg", id.count == 36,
                  UUID(uuidString: id) != nil else { return false }
            return try isRegularFile(url)
        }
    }
}

public enum PhotoRepositoryError: Error, LocalizedError, Equatable {
    case invalidIdentifier(String)
    case emptyData
    case missingPhoto(String)

    public var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            "写真の識別情報が正しくありません。"
        case .emptyData:
            "写真のデータを読み込めませんでした。"
        case .missingPhoto:
            "写真のファイルが見つかりません。もう一度写真を追加してください。"
        }
    }
}
