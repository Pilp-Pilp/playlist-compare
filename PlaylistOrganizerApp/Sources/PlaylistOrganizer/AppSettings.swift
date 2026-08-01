import Foundation

struct SortField: Codable, Identifiable, Equatable {
    var id = UUID()
    var field: String
    var descending: Bool
}

final class AppSettings: ObservableObject {
    static let availableFields = ["artist", "album", "name", "genre", "year", "plays", "dateadded"]

    static let fieldLabels: [String: String] = [
        "artist": "Artist",
        "album": "Album",
        "name": "Name",
        "genre": "Genre",
        "year": "Year",
        "plays": "Plays",
        "dateadded": "Date Added",
    ]

    static let defaultSortFields = [
        SortField(field: "artist", descending: false),
        SortField(field: "album", descending: false),
        SortField(field: "name", descending: false),
    ]

    private static let defaultsKey = "reorderSortFields"

    @Published var sortFields: [SortField] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([SortField].self, from: data),
           !decoded.isEmpty {
            sortFields = decoded
        } else {
            sortFields = Self.defaultSortFields
        }
    }

    var sortSpec: String {
        sortFields.map { "\($0.field):\($0.descending ? "desc" : "asc")" }.joined(separator: ",")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sortFields) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
