import Testing
import Shared

struct PipeMessagesTests {
    @Test func exit() {
        let bytes = PipeMessages.exit.toBytes()
        let message = PipeMessages.fromBytes(bytes)!
        guard case .exit = message else {
            Issue.record("Expected .exit, got \(message)")
            return
        }
    }

    @Test func clipCursor() {
        let rect = Rect(left: 1, top: 2, right: 3, bottom: 4)
        let bytes = PipeMessages.clipCursor(rect).toBytes()
        let message = PipeMessages.fromBytes(bytes)!
        guard case let .clipCursor(messageRect) = message else {
            Issue.record("Expected .clipCursor, got \(message)")
            return
        }
        #expect(messageRect.left == 1)
        #expect(messageRect.top == 2)
        #expect(messageRect.right == 3)
        #expect(messageRect.bottom == 4)
    }

    @Test func setCursorPos() {
        let pos = Pos(x: 1, y: 2)
        let bytes = PipeMessages.setCursorPos(pos).toBytes()
        let message = PipeMessages.fromBytes(bytes)!
        guard case let .setCursorPos(messagePos) = message else {
            Issue.record("Expected .setCursorPos, got \(message)")
            return
        }
        #expect(messagePos.x == 1)
        #expect(messagePos.y == 2)
    }

    @Test func speak() {
        let speak = Speak(text: "Hello, world!", flags: 1)
        let bytes = PipeMessages.speak(speak).toBytes()
        let message = PipeMessages.fromBytes(bytes)!
        guard case let .speak(messageSpeak) = message else {
            Issue.record("Expected .speak, got \(message)")
            return
        }
        #expect(messageSpeak.text == "Hello, world!")
        #expect(messageSpeak.flags == 1)
    }

    @Test func speakSkip() {
        let bytes = PipeMessages.speakSkip.toBytes()
        let message = PipeMessages.fromBytes(bytes)!
        guard case .speakSkip = message else {
            Issue.record("Expected .speakSkip, got \(message)")
            return
        }
    }
}