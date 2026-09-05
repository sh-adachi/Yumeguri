import SwiftUI

enum YuTheme {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let pine = Color(red: 0.20, green: 0.34, blue: 0.29)
    static let ink = Color(red: 0.15, green: 0.23, blue: 0.20)
    static let muted = Color(red: 0.44, green: 0.48, blue: 0.44)
    static let sage = Color(red: 0.88, green: 0.91, blue: 0.85)
    static let gold = Color(red: 0.64, green: 0.45, blue: 0.23)
    static let clay = Color(red: 0.63, green: 0.34, blue: 0.27)
    static let line = Color(red: 0.86, green: 0.87, blue: 0.82)
}

struct OnsenEmblem: View {
    var size: CGFloat = 42
    var filled = false
    var body: some View {
        OnsenMark()
            .stroke(style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round, lineJoin: .round))
            .foregroundStyle(filled ? .white : YuTheme.pine)
            .padding(size * 0.18)
            .frame(width: size, height: size)
            .background(filled ? YuTheme.pine : YuTheme.sage, in: RoundedRectangle(cornerRadius: size * 0.32))
            .accessibilityHidden(true)
    }
}

/// A resolution-independent bath-and-steam mark, without emoji font dependencies.
struct OnsenMark: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        var path = Path()
        path.move(to: point(0.13, 0.62))
        path.addCurve(to: point(0.87, 0.62), control1: point(0.01, 1.03), control2: point(0.99, 1.03))
        path.move(to: point(0.28, 0.68))
        path.addCurve(to: point(0.72, 0.68), control1: point(0.42, 0.76), control2: point(0.58, 0.76))
        for x: CGFloat in [0.30, 0.50, 0.70] {
            path.move(to: point(x, 0.52))
            path.addCurve(to: point(x + 0.01, 0.09), control1: point(x - 0.12, 0.37), control2: point(x + 0.12, 0.25))
        }
        return path
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(YuTheme.ink)
            Spacer()
            Text(subtitle).font(.caption).foregroundStyle(YuTheme.muted)
        }
    }
}

struct StatusPill: View {
    let status: VisitStatus
    var body: some View {
        Label(status.title, systemImage: status == .visited ? "checkmark.circle.fill" : "bookmark.fill")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 6)
            .foregroundStyle(status == .visited ? YuTheme.pine : YuTheme.gold)
            .background(status == .visited ? YuTheme.sage : Color(red: 0.97, green: 0.92, blue: 0.82), in: Capsule())
    }
}

struct SpotRow: View {
    let spot: OnsenSpot
    var record: OnsenRecord?
    var index: Int = 0
    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let photoID = record?.photoIDs.first {
                    StoredPhotoView(photoID: photoID, maxPixelSize: 220)
                } else {
                    emblemTile
                }
            }
            .frame(width: 66, height: 72).clipped().clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(spot.name).font(.system(.body, weight: .semibold)).foregroundStyle(YuTheme.ink).lineLimit(2)
                Text(spot.address).font(.caption).foregroundStyle(YuTheme.muted).lineLimit(1)
                if let record {
                    HStack(spacing: 8) {
                        StatusPill(status: record.status)
                        if let rating = record.rating, record.status == .visited {
                            Text(rating.title).font(.caption.weight(.medium)).foregroundStyle(YuTheme.pine)
                        }
                        if !record.photoIDs.isEmpty {
                            Label("\(record.photoIDs.count)", systemImage: "photo")
                                .font(.system(size: 10)).foregroundStyle(YuTheme.muted)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(YuTheme.muted)
        }
        .padding(14)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
        .contentShape(Rectangle())
    }

    private var emblemTile: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 18)
                .fill([YuTheme.sage, Color(red: 0.91, green: 0.87, blue: 0.80), Color(red: 0.84, green: 0.90, blue: 0.90)][index % 3])
            Image(systemName: "mountain.2.fill").font(.system(size: 38)).foregroundStyle(YuTheme.pine.opacity(0.12)).offset(x: 8, y: 6)
            OnsenMark().stroke(style: StrokeStyle(lineWidth: 2.1, lineCap: .round)).foregroundStyle(YuTheme.pine).frame(width: 37, height: 37).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(YuTheme.pine.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
