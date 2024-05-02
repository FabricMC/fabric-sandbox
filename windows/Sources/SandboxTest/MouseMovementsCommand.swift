import WinSDK

// Call SetCursorPos and ClipCursor to ensure that they work within the sandbox

class MouseMovementsCommand: Command {
  func execute(_ arguments: [String]) throws {
    SetCursorPos(100, 100)

    var rect = RECT(left: 0, top: 0, right: 100, bottom: 100)
    ClipCursor(&rect)

    ClipCursor(nil)
  }
}
