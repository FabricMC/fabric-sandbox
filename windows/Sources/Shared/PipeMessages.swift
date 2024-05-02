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

public enum PipeMessages {
  case exit
  case clipCursor(Rect)
  case setCursorPos(Pos)

  // Convert the message from a cvs string
  public static func fromString(_ message: String) -> PipeMessages? {
    let csv = message.split(separator: ",")
    guard csv.count > 1 else {
      return nil
    }

    switch csv[0] {
    case "exit":
      return .exit
    case "clipCursor":
      guard csv.count == 5,
        let left = Int32(csv[1]),
        let top = Int32(csv[2]),
        let right = Int32(csv[3]),
        let bottom = Int32(csv[4])
      else {
        return nil
      }
      return .clipCursor(Rect(left: left, top: top, right: right, bottom: bottom))
    case "setCursorPos":
      guard csv.count == 3,
        let x = Int32(csv[1]),
        let y = Int32(csv[2])
      else {
        return nil
      }
      return .setCursorPos(Pos(x: x, y: y))
    default:
      return nil
    }
  }

  // Convert the message to a csv string
  public func toString() -> String {
    switch self {
    case .exit:
      return "exit"
    case .clipCursor(let rect):
      return "clipCursor,\(rect.left),\(rect.top),\(rect.right),\(rect.bottom)"
    case .setCursorPos(let pos):
      return "setCursorPos,\(pos.x),\(pos.y)"
    }
  }
}
