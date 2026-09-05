import Foundation

public enum OnsenCatalog {
    /// Starter destinations, not saved visits. Coordinates are approximate landmark / town-center
    /// positions for discovery; they do not assert an entrance, opening hours, or bathing availability.
    /// Linked official tourism / facility sites provide current destination information.
    public static let spots: [OnsenSpot] = [
        OnsenSpot(
            id: "catalog-kusatsu-yubatake",
            name: "草津温泉・湯畑",
            address: "群馬県吾妻郡草津町草津",
            latitude: 36.6229, longitude: 138.5964,
            websiteURL: URL(string: "https://www.kusatsu-onsen.ne.jp/kankou/1004.php")
        ),
        OnsenSpot(
            id: "catalog-hakone-yumoto",
            name: "箱根湯本温泉・温泉街",
            address: "神奈川県足柄下郡箱根町湯本",
            latitude: 35.2313, longitude: 139.1006,
            websiteURL: URL(string: "https://www.hakoneyumoto.com/")
        ),
        OnsenSpot(
            id: "catalog-ginzan",
            name: "銀山温泉・温泉街",
            address: "山形県尾花沢市銀山新畑",
            latitude: 38.5706, longitude: 140.5301,
            websiteURL: URL(string: "https://www.ginzanonsen.jp/")
        ),
        OnsenSpot(
            id: "catalog-kinosaki-ichinoyu",
            name: "城崎温泉・一の湯",
            address: "兵庫県豊岡市城崎町湯島",
            latitude: 35.6268, longitude: 134.8091,
            websiteURL: URL(string: "https://kinosaki-spa.gr.jp/")
        ),
        OnsenSpot(
            id: "catalog-arima-kinnoyu",
            name: "有馬温泉・金の湯",
            address: "兵庫県神戸市北区有馬町",
            latitude: 34.7970, longitude: 135.2482,
            websiteURL: URL(string: "https://arimaspa-kingin.jp/")
        ),
        OnsenSpot(
            id: "catalog-dogo-honkan",
            name: "道後温泉本館",
            address: "愛媛県松山市道後湯之町5-6",
            latitude: 33.8520, longitude: 132.7864,
            websiteURL: URL(string: "https://dogo.jp/")
        ),
        OnsenSpot(
            id: "catalog-beppu-takegawara",
            name: "別府温泉・竹瓦温泉",
            address: "大分県別府市元町16-23",
            latitude: 33.2775, longitude: 131.5067,
            websiteURL: URL(string: "https://www.takegawara-onsen.com/")
        ),
        OnsenSpot(
            id: "catalog-kurokawa",
            name: "黒川温泉・温泉街",
            address: "熊本県阿蘇郡南小国町満願寺",
            latitude: 33.0788, longitude: 131.1425,
            websiteURL: URL(string: "https://www.kurokawaonsen.or.jp/")
        ),
        OnsenSpot(
            id: "catalog-gero",
            name: "下呂温泉・温泉街",
            address: "岐阜県下呂市湯之島",
            latitude: 35.8080, longitude: 137.2407,
            websiteURL: URL(string: "https://www.gero-spa.com/")
        ),
        OnsenSpot(
            id: "catalog-noboribetsu",
            name: "登別温泉・温泉街",
            address: "北海道登別市登別温泉町",
            latitude: 42.4934, longitude: 141.1427,
            websiteURL: URL(string: "https://noboribetsu-spa.jp/")
        )
    ]
}
