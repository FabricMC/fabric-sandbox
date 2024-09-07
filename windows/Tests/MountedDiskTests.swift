import Testing
import WinSDK
import WindowsUtils

@testable import FabricSandbox
@testable import Sandbox

@Suite(.serialized) struct MountedDiskTests {
  @Test func testGetUsedDriveLetters() throws {
    let drives = MountedDisk.getUsedDriveLetters()
    #expect(drives.contains("C"))
  }

  @Test func testGetNextDriveLetter() throws {
    let nextDrive = MountedDisk.getNextDriveLetter(perfered: "S")
    print("Next drive: \(nextDrive ?? "?")")
  }

  @Test func testMountDrive() throws {
    let nextDrive = MountedDisk.getNextDriveLetter(perfered: "S")
    guard let nextDrive = nextDrive else {
      Issue.record()
      return
    }

    let tempDir = try createTempDir()
    defer {
      try! tempDir.delete()
    }

    // Write a file to the temporary directory
    try tempDir.child("test.txt").writeString("Hello, World!")

    #expect(!MountedDisk.getUsedDriveLetters().contains(nextDrive))

    // Mount the temporary directory to the next available drive letter
    let mountedDisk = try MountedDisk(path: tempDir, driveLetter: nextDrive)
    defer {
      try! mountedDisk.unmount()
      #expect(!MountedDisk.getUsedDriveLetters().contains(nextDrive))
    }

    #expect(MountedDisk.getUsedDriveLetters().contains(nextDrive))

    // Read the file from the mounted drive
    let mountedFile = File("\(nextDrive):/test.txt")
    let contents = try mountedFile.readString()
    #expect(contents == "Hello, World!")
  }
}
