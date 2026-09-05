import Foundation

public enum VisitStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case wantToGo
    case visited

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wantToGo: "行きたい"
        case .visited: "行った"
        }
    }

    public var symbolName: String {
        switch self {
        case .wantToGo: "bookmark.fill"
        case .visited: "checkmark.seal.fill"
        }
    }
}

public enum OnsenRating: String, Codable, CaseIterable, Identifiable, Sendable {
    case bad
    case average
    case good

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bad: "悪い"
        case .average: "普通"
        case .good: "良い"
        }
    }

    public var symbolName: String {
        switch self {
        case .bad: "cloud"
        case .average: "cloud.sun"
        case .good: "sun.max"
        }
    }
}

public struct OnsenSpot: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var address: String
    public var latitude: Double
    public var longitude: Double
    public var phoneNumber: String?
    public var websiteURL: URL?

    public init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        phoneNumber: String? = nil,
        websiteURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
    }
}

public struct OnsenRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String { spot.id }
    public var spot: OnsenSpot
    public var status: VisitStatus {
        didSet {
            if status == .wantToGo {
                rating = nil
                visitedOn = nil
            }
        }
    }
    public var rating: OnsenRating?
    public var visitedOn: Date?
    public var memo: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        spot: OnsenSpot,
        status: VisitStatus = .wantToGo,
        rating: OnsenRating? = nil,
        visitedOn: Date? = nil,
        memo: String = "",
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.spot = spot
        self.status = status
        self.rating = status == .visited ? rating : nil
        self.visitedOn = status == .visited ? visitedOn : nil
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// Keeps imported and directly edited records consistent with their visit status.
    public func normalized() -> OnsenRecord {
        OnsenRecord(
            spot: spot,
            status: status,
            rating: rating,
            visitedOn: visitedOn,
            memo: memo,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case spot, status, rating, visitedOn, memo, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try values.decode(Date.self, forKey: .createdAt)
        self.init(
            spot: try values.decode(OnsenSpot.self, forKey: .spot),
            status: try values.decode(VisitStatus.self, forKey: .status),
            rating: try values.decodeIfPresent(OnsenRating.self, forKey: .rating),
            visitedOn: try values.decodeIfPresent(Date.self, forKey: .visitedOn),
            memo: try values.decodeIfPresent(String.self, forKey: .memo) ?? "",
            createdAt: createdAt,
            updatedAt: try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        )
    }
}
