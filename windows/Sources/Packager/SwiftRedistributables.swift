import WindowsUtils

class SwiftRedistributables {
  /// Returns a map of a file name to the file path
  static func extractRedistributables(arch: Architecture, out: File) throws -> [String: File] {
    try resetDir(out)

    let redistributables = try swiftRedistributables()
    let versionedDir = try redistributables.directoryContents().first

    guard let versionDir = versionedDir else {
      throw PackagerError("Could not find versioned directory in \(redistributables)")
    }

    let archName = arch == .arm64 ? "arm64" : "amd64"
    let rtl = versionDir.child("rtl.\(archName).msm")

    guard rtl.exists() else {
      throw PackagerError("Could not find \(rtl)")
    }

    let metadataXml = out.child("metadata.xml")

    let _ = try run(
      File("wix.exe"),
      args: [
        "msi", "decompile", "-x", out.path(), "-o", metadataXml.path(), rtl.path(),
      ], searchPath: true)

    let metadata = parseMetaData(xml: try metadataXml.readString())
    return metadata.mapValues { out.child(String($0.dropFirst("SourceDir\\".count))) }
  }

  private static func parseMetaData(xml: String) -> [String: String] {
    var result: [String: String] = [:]
    let lines = xml.split(separator: "</Component>")

    for line in lines {
      if line.contains("<File ") {
        let parts = line.split(separator: " ")
        var name: String?
        var source: String?

        for part in parts {
          if part.contains("Name") && !part.contains("ShortName") {
            name = String(part.split(separator: "\"")[1])
          } else if part.contains("Source") {
            source = String(part.split(separator: "\"")[1])
          }
        }

        if let name = name, let source = source {
          result[name] = source
        }
      }
    }

    return result
  }

  static func getWixVersion() throws -> String {
    return try run(File("wix.exe"), args: ["--version"], searchPath: true)
  }

  static func swiftRedistributables() throws -> File {
    let appData = try getEnvironmentVarible("LOCALAPPDATA")
    guard let appData = appData else {
      throw PackagerError("APPDALOCALAPPDATATA environment variable not found")
    }

    return File(appData).child("Programs").child("Swift").child("Redistributables")
  }
}
