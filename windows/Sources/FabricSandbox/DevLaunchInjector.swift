// A pure swift implementation of the dev-launch-injector parser
// See: https://github.com/FabricMC/dev-launch-injector/blob/master/src/net/fabricmc/devlaunchinjector/Main.java
import WindowsUtils

// Locate the -Dfabric.dli.config= argument and parse the config
// Then applies the arguments

public struct DevLaunchInjector {
  public let properties: [Side: [String: String?]]
  public let args: [Side: [String]]

  public init(fromString data: String) throws {
    var properties: [Side: [String: String]] = [:]
    var args: [Side: [String]] = [:]

    let lines = data.split(separator: "\n")
    var state = ParseState.none

    for line in lines {
      if line.isEmpty {
        continue
      }

      let indented = line.starts(with: " ") || line.starts(with: "\t")
      let line = line.trimmed()

      if line.isEmpty {
        continue
      }

      if !indented {
        var side: Side? = nil
        var offset = -1

        for s in Side.allCases {
          if line.starts(with: s.rawValue) {
            side = s
            offset = s.rawValue.count
            break
          }
        }

        guard let side = side else {
          state = .skip
          continue
        }

        switch line.dropFirst(offset) {
        case "Properties":
          state = .properties(side)
        case "Args":
          state = .args(side)
        default:
          throw DLIParseError("invalid attribute: \(line)")
        }
      } else if case .none = state {
        throw DLIParseError("value without preceding attribute: \(line)")
      } else if case .properties(let side) = state {
        let pos = line.firstIndex(of: "=")
        let key = pos != nil ? line[..<pos!].trimmed() : line
        let value = pos != nil ? line[line.index(after: pos!)...].trimmed() : nil
        properties[side, default: [:]][key] = value
      } else if case .args(let side) = state {
        args[side, default: []].append(line)
      } else if case .skip = state {
        continue
      }
    }

    self.properties = properties
    self.args = args
  }

  public func expandProps(_ sides: [Side] = [.common, .client]) -> [String] {
    return sides.flatMap { expandProp($0) }
  }

  private func expandProp(_ side: Side) -> [String] {
    return properties[side]?.map {
      if let value = $0.value {
        return "-D\($0.key)=\(value)"
      } else {
        return "-D\($0.key)"
      }
    } ?? []
  }

  public func expandArgs(_ sides: [Side] = [.common, .client]) -> [String] {
    return sides.flatMap { args[$0] ?? [] }
  }
}
public func applyDevLaunchInjectorArgs(_ args: [String], sides: [Side] = [.common, .client]) throws
  -> [String]
{
  guard let dliConfig = args.first(where: { $0.starts(with: "-Dfabric.dli.config=") }) else {
    // Not using dli, just return the args
    return args
  }

  let configFile = File(String(dliConfig.dropFirst("-Dfabric.dli.config=".count)))

  guard configFile.exists() else {
    logger.warning("DLI config file does not exist at path: \(configFile)")
    return args
  }

  let dli = try DevLaunchInjector(fromString: try configFile.readString())

  var newArgs: [String] = []

  for arg in args {
    if arg.starts(with: "-Dfabric.dli.config=") {
      // Replace the dli config argument with the expanded JVM arguments
      newArgs.append(contentsOf: dli.expandProps(sides))
      continue
    }

    newArgs.append(arg)
  }

  // Append the expanded program arguments
  newArgs.append(contentsOf: dli.expandArgs(sides))

  return newArgs
}
public enum Side: String, CaseIterable {
  case client
  case server
  case common
}
public struct DLIParseError: Error {
  let message: String

  public init(_ message: String) {
    self.message = message
  }
}
private enum ParseState {
  case none
  case args(Side)
  case properties(Side)
  case skip
}
