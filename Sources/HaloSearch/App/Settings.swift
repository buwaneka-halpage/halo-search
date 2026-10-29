import Carbon.HIToolbox
import Foundation

struct HotKeyPreset: Equatable {
    let id: String
    let title: String
    let keyCode: UInt32
    let modifiers: UInt32

    static let all: [HotKeyPreset] = [
        HotKeyPreset(id: "ctrl-shift-space", title: "⌃⇧Space",
                     keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | shiftKey)),
        HotKeyPreset(id: "opt-shift-space", title: "⌥⇧Space",
                     keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | shiftKey)),
        HotKeyPreset(id: "cmd-shift-1", title: "⇧⌘1",
                     keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey | shiftKey)),
        HotKeyPreset(id: "ctrl-opt-s", title: "⌃⌥S",
                     keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey)),
        HotKeyPreset(id: "f19", title: "F19",
                     keyCode: UInt32(kVK_F19), modifiers: 0),
    ]
}

enum ResultTab: String, CaseIterable {
    case aiMode
    case search

    var title: String {
        switch self {
        case .aiMode: return "AI Mode"
        case .search: return "Search"
        }
    }
}

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var hotKey: HotKeyPreset {
        get {
            let id = defaults.string(forKey: "hotKey")
            return HotKeyPreset.all.first { $0.id == id } ?? HotKeyPreset.all[0]
        }
        set { defaults.set(newValue.id, forKey: "hotKey") }
    }

    var defaultTab: ResultTab {
        get { ResultTab(rawValue: defaults.string(forKey: "defaultTab") ?? "") ?? .aiMode }
        set { defaults.set(newValue.rawValue, forKey: "defaultTab") }
    }

    /// The question AI Mode is asked about a circled image.
    var imagePrompt: String {
        get { defaults.string(forKey: "imagePrompt") ?? "What is this?" }
        set { defaults.set(newValue, forKey: "imagePrompt") }
    }
}
