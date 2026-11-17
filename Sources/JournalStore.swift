import Foundation
import Combine

struct JournalFile {
    let url: URL

    static var local: JournalFile {
        let directory = URL.applicationSupportDirectory.appending(path: "JobQuest", directoryHint: .isDirectory)
        return JournalFile(url: directory.appending(path: "journal.json", directoryHint: .notDirectory))
    }

    func load() throws -> Journal {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Journal()
        }
        return try JSONDecoder().decode(Journal.self, from: data)
    }

    func save(_ journal: Journal) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(journal).write(to: url, options: .atomic)
    }
}

@MainActor
final class JournalStore: ObservableObject {
    private let file: JournalFile
    @Published private(set) var journal = Journal()
    @Published private(set) var loadError: String?
    @Published var saveError: String?

    init(file: JournalFile = .local) {
        self.file = file
        reload()
    }

    func reload() {
        do {
            journal = try file.load()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    @discardableResult
    func update(_ change: (inout Journal) -> Bool) -> Bool {
        guard loadError == nil else { return false }
        var draft = journal
        guard change(&draft) else { return false }
        do {
            try file.save(draft)
            journal = draft
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
