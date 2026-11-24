import Foundation

struct SavedLink: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var date: Date = Date()
}

final class LibraryStore: ObservableObject {
    @Published private(set) var bookmarks: [SavedLink] = []
    @Published private(set) var history: [SavedLink] = []

    private let bookmarksKey = "cr.bookmarks"
    private let historyKey = "cr.history"

    init() {
        bookmarks = load(bookmarksKey)
        history = load(historyKey)
    }

    private func load(_ key: String) -> [SavedLink] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([SavedLink].self, from: data) else { return [] }
        return list
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func isBookmarked(_ url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    @discardableResult
    func toggleBookmark(title: String, url: String) -> Bool {
        if let index = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: index)
            persist()
            return false
        }
        bookmarks.insert(SavedLink(title: title.isEmpty ? url : title, url: url), at: 0)
        persist()
        return true
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persist()
    }

    func record(title: String, url: String) {
        guard url.hasPrefix("http") else { return }
        if let last = history.first, last.url == url { return }
        history.insert(SavedLink(title: title.isEmpty ? url : title, url: url), at: 0)
        if history.count > 200 { history = Array(history.prefix(200)) }
        persist()
    }

    func clearHistory() {
        history.removeAll()
        persist()
    }
}
