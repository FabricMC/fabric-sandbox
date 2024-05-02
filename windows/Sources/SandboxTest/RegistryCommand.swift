import WindowsUtils

class RegistryCommand: Command {
  func execute(_ arguments: [String]) throws {
    let subcommand = arguments.first ?? ""

    switch subcommand {
    case "create":
      try createKey()
    case "write":
      try writeKey()
    default:
      fatalError("Unknown subcommand: \(subcommand)")
    }
  }

  func createKey() throws {
    print("CreateKey test")
    let hive = Hive.currentUser
    let key = "SOFTWARE\\FabricSandbox"

    do {
      let exists = try Registry.createKey(hive: hive, key: key)
      print("Key created: \(exists)")
    } catch let error as Win32Error {
      print("Failed to create key: \(error)")
    }
  }

  // This is an ovioubs attack vector, this test confirms that a process cannot write to the auto run key
  func writeKey() throws {
    print("WriteKey test")
    let autoRun = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"

    do {
      try Registry.setStringValue(
        hive: Hive.currentUser, key: autoRun, name: "TestKey", value: "Test.exe")
    } catch let error as Win32Error {
      print("Failed to write user key: \(error)")
    }

    do {
      try Registry.setStringValue(
        hive: Hive.localMachine, key: autoRun, name: "TestKey", value: "Test.exe")
    } catch let error as Win32Error {
      print("Failed to write local machine key: \(error)")
    }
  }
}
