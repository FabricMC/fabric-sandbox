import Testing
import WindowsUtils

struct FileTests {
  @Test func createFile() throws {
    let file = File("C:/Users/Test/Documents")
    #expect(file.path() == "C:/Users/Test/Documents")
  }

  @Test func createFileWithBackslashes() throws {
    let file = File("C:\\Users\\Test\\Documents")
    #expect(file.path() == "C:/Users/Test/Documents")
  }

  @Test func createFileWithMixedSeparators() throws {
    let file = File("C:/Users\\Test/Documents")
    #expect(file.path() == "C:/Users/Test/Documents")
  }

  @Test func parent() throws {
    let file = File("C:/Users/Test/Documents")
    #expect(file.parent()!.path() == "C:/Users/Test")
  }

  @Test func childDirectory() throws {
    let file = File("C:/Users/Test")
    #expect(file.child("Documents").path() == "C:/Users/Test/Documents")
  }

  @Test func childFile() throws {
    let file = File("C:/Users/Test")
    #expect(file.child("file.txt").path() == "C:/Users/Test/file.txt")
  }

  @Test func childSubFile() throws {
    let file = File("C:/Users/Test")
    #expect(file.child("foo\\file.txt").path() == "C:/Users/Test/foo/file.txt")
  }

  @Test func root() throws {
    let file = File("C:/Users/Test/Documents")
    #expect(file.root().path() == "C:")
  }

  @Test func parentOfRoot() throws {
    let file = File("C:/")
    #expect(file.parent() == nil)
  }

  @Test func exists() throws {
    let file = File("C:/Users")
    #expect(file.exists())
  }

  @Test func doesNotExist() throws {
    let file = File("C:/Users/DoesNotExist")
    #expect(!file.exists())
  }

  @Test func createRandomChild() throws {
    let file = try File.getTempDirectory()
    let child = file.randomChild(ext: ".txt")
    let ext: String = child.ext()!
    #expect(ext == "txt")
  }

  @Test func createDirectoryReccurisve() throws {
    let file = try File.getTempDirectory()
    let child = file.randomChild().child("hello")
    try child.createDirectory()
    #expect(child.exists())
  }

  @Test func deleteDirectory() throws {
    let file = try File.getTempDirectory()
    let child = file.randomChild()
    try child.createDirectory()
    #expect(child.exists())
    try child.delete()
    #expect(!child.exists())
  }

  @Test func deleteFile() throws {
    let file = try File.getTempDirectory()
    let child = file.randomChild()
    try child.touch()
    #expect(child.exists())
    try child.delete()
    #expect(!child.exists())
  }

  @Test func readWriteFile() throws {
    let file = try File.getTempDirectory().randomChild()
    let str = "Hello, World!"
    try file.writeString(str)
    let size = try file.size()
    #expect(size == str.utf8.count)
    let readStr = try file.readString()
    #expect(readStr == str)
  }

  @Test func readWriteLargeFile() throws {
    let file = try File.getTempDirectory().randomChild()
    let str = String(repeating: "A", count: 1024 * 1024)
    try file.writeString(str)
    let readStr = try file.readString()
    #expect(readStr == str)
  }

  @Test func copyFile() throws {
    let tempDir = try File.getTempDirectory().randomChild()
    try tempDir.createDirectory()
    defer { try! tempDir.delete() }

    let source = tempDir.child("source.txt")
    let dest = tempDir.child("dest.txt")
    try source.writeString("Hello, World!")
    try source.copy(to: dest)
    #expect(dest.exists())
    let readStr = try dest.readString()
    #expect(readStr == "Hello, World!")
  }

  @Test func listContents() throws {
    let tempDir = try File.getTempDirectory().randomChild()
    try tempDir.createDirectory()
    defer { try! tempDir.delete() }

    for i in 0..<10 {
      let child = tempDir.child("child_\(i).txt")
      try child.touch()
    }

    let contents = try tempDir.directoryContents()
    #expect(contents.count == 10)

    let sorted = contents.sorted { $0.name() < $1.name() }
    for i in 0..<10 {
      #expect(sorted[i].name() == "child_\(i).txt")
    }
  }

  @Test func relativePath() throws {
    let file = File("C:\\foo\\bar\\baz.txt")
    let relative = file.relative(to: File("C:\\foo"))
    #expect(relative == "bar\\baz.txt")
  }

  @Test func isChild() throws {
    let file = File("C:\\foo\\bar\\baz.txt")
    #expect(file.isChild(of: File("C:\\foo")))
    #expect(!file.isChild(of: File("C:\\buzz")))
  }
}
