import WindowsUtils

func createTempDir() throws -> File {
  let tempDir = try File.getTempDirectory().randomChild()
  try tempDir.createDirectory()
  return tempDir
}
