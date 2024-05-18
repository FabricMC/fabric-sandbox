import WinSDK

public struct Pos {
  public var x: Int32
  public var y: Int32

  public init(x: Int32, y: Int32) {
    self.x = x
    self.y = y
  }
}

public struct Rect {
  public var left: Int32
  public var top: Int32
  public var right: Int32
  public var bottom: Int32

  public init(left: Int32, top: Int32, right: Int32, bottom: Int32) {
    self.left = left
    self.top = top
    self.right = right
    self.bottom = bottom
  }
}

public struct Speak {
  public var text: String
  public var flags: UInt32

  public init(text: String, flags: UInt32) {
    self.text = text
    self.flags = flags
  }
}

public enum PipeMessages {
  case exit
  case clipCursor(Rect)
  case setCursorPos(Pos)
  case speak(Speak)
  case speakSkip

  private var rawValue: UInt8 {
    switch self {
    case .exit: return 0
    case .clipCursor: return 1
    case .setCursorPos: return 2
    case .speak: return 3
    case .speakSkip: return 4
    }
  }

  // Convert the message from a byte array
  public static func fromBytes(_ bytes: [UInt16]) -> PipeMessages? {
    guard bytes.count >= 1 else {
      return nil
    }

    let buffer = ByteBuffer(data: bytes)
    let type = buffer.readUInt8()!

    switch type {
    case 0:
      return .exit
    case 1:
      let left = buffer.readInt32()
      let top = buffer.readInt32()
      let right = buffer.readInt32()
      let bottom = buffer.readInt32()
      guard let left = left, let top = top, let right = right, let bottom = bottom else {
        return nil
      }
      return .clipCursor(Rect(
        left: left,
        top: top,
        right: right,
        bottom: bottom
      ))
    case 2:
      let x = buffer.readInt32()
      let y = buffer.readInt32()
      guard let x = x, let y = y else {
        return nil
      }
      return .setCursorPos(Pos(
        x: x,
        y: y
      ))
    case 3:
      let text = buffer.readString()
      let flags = buffer.readUInt32()
      guard let text = text, let flags = flags else {
        return nil
      }
      return .speak(Speak(
        text: text,
        flags: flags
      ))
    case 4:
      return .speakSkip
    default:
      return nil
    }
  }

  // Convert the message to a byte array
  // The first byte is the message type, the rest is the message data
  public func toBytes() -> [UInt16] {
    let buffer = ByteBuffer()
    buffer.appendUInt8(rawValue)

    switch self {
    case .exit:
      break
    case .clipCursor(let rect):
      buffer.appendInt32(rect.left)
      buffer.appendInt32(rect.top)
      buffer.appendInt32(rect.right)
      buffer.appendInt32(rect.bottom)
    case .setCursorPos(let pos):
      buffer.appendInt32(pos.x)
      buffer.appendInt32(pos.y)
    case .speak(let speak):
      buffer.appendString(speak.text)
      buffer.appendUInt32(speak.flags)
    case .speakSkip:
      break
    }
    return buffer.data
  }
}

private class ByteBuffer {
  var data: [UInt16]

  init() {
    data = []
  }

  init(data: [UInt16]) {
    self.data = data
  }

  var size : Int {
    return data.count
  }

  func appendUInt8(_ value: UInt8) {
    data.append(UInt16(value))
  }

  func appendUInt(_ value: UInt) {
    appendUInt8(UInt8(value & 0xFF))
    appendUInt8(UInt8((value >> 8) & 0xFF))
  }

  func appendInt(_ value: Int) {
    appendUInt(UInt(bitPattern: value))
  }

  func appendUInt32(_ value: UInt32) {
    appendUInt8(UInt8(value & 0xFF))
    appendUInt8(UInt8((value >> 8) & 0xFF))
    appendUInt8(UInt8((value >> 16) & 0xFF))
    appendUInt8(UInt8((value >> 24) & 0xFF))
  }

  func appendInt32(_ value: Int32) {
    appendUInt32(UInt32(bitPattern: value))
  }

  func appendString(_ string: String) {
    appendInt(string.utf8.count)
    data.append(contentsOf: string.utf16)
  }

  func readUInt8() -> UInt8? {
    guard !data.isEmpty else {
      return nil
    }
    let value = data[0]
    data.removeFirst()
    return UInt8(value)
  }

  func readUInt() -> UInt? {
    let one = readUInt8()
    let two = readUInt8()
    guard let one = one, let two = two else {
      return nil
    }
    return UInt(one) | UInt(two) << 8
  }

  func readInt() -> Int? {
    guard let value = readUInt() else {
      return nil
    }
    return Int(bitPattern: value)
  }

  func readUInt32() -> UInt32? {
    let one = readUInt8()
    let two = readUInt8()
    let three = readUInt8()
    let four = readUInt8()
    guard let one = one, let two = two, let three = three, let four = four else {
      return nil
    }
    return UInt32(one) | UInt32(two) << 8 | UInt32(three) << 16 | UInt32(four) << 24
  }

  func readInt32() -> Int32? {
    guard let value = readUInt32() else {
      return nil
    }
    return Int32(bitPattern: value)
  }

  func readString() -> String? {
    guard let length = readInt() else {
      return nil
    }

    guard data.count >= length else {
      return nil
    }

    let string = String(decoding: data[0..<Int(length)], as: UTF16.self)
    data.removeFirst(Int(length))
    return string
  }
}