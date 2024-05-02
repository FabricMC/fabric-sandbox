import WindowsUtils

func createTempDir(ext: String? = nil) throws -> File {
  let tempDir = try File.getTempDirectory().randomChild(ext: ext)
  try tempDir.createDirectory()
  return tempDir
}
