import Foundation

struct AccountDetailRenameState: Equatable {
    var isPresented = false
    var draft = ""

    var cleanedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func begin(alias: String) {
        draft = alias
        isPresented = true
    }

    mutating func cancel() {
        isPresented = false
    }

    mutating func finish() {
        isPresented = false
    }

    mutating func reset(alias: String) {
        draft = alias
        isPresented = false
    }

    mutating func sync(alias: String) {
        draft = alias
    }
}
