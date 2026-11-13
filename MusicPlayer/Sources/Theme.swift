import SwiftUI

/// Same palette as the Windows build (src/Controls.cs).
enum Theme {
    static let canvas = Color(red: 15 / 255, green: 15 / 255, blue: 17 / 255)
    static let surface = Color(red: 23 / 255, green: 23 / 255, blue: 27 / 255)
    static let hover = Color(red: 35 / 255, green: 35 / 255, blue: 42 / 255)
    static let track = Color(red: 51 / 255, green: 51 / 255, blue: 61 / 255)
    static let text = Color(red: 238 / 255, green: 238 / 255, blue: 242 / 255)
    static let muted = Color(red: 140 / 255, green: 140 / 255, blue: 152 / 255)
    static let accent = Color(red: 124 / 255, green: 170 / 255, blue: 255 / 255)
    static let accentDeep = Color(red: 88 / 255, green: 136 / 255, blue: 232 / 255)
    static let accentInk = Color(red: 17 / 255, green: 20 / 255, blue: 30 / 255)
    static let stroke = Color.white.opacity(0.09)
}
