import Testing
import WindowsUtils

struct RegistryTests {
  @Test func string() throws {
    let hive = Hive.currentUser
    let key = "SOFTWARE\\FabricSandbox"

    let value = try Registry.getStringValue(hive: hive, key: key, name: "TestKey")
    #expect(value == nil)

    let _ = try Registry.createKey(hive: hive, key: key)
    try Registry.setStringValue(hive: hive, key: key, name: "TestKey", value: "TestValue")

    let newValue = try Registry.getStringValue(hive: hive, key: key, name: "TestKey")
    #expect(newValue == "TestValue")

    try Registry.deleteValue(hive: hive, key: key, name: "TestKey")

    let deletedValue = try Registry.getStringValue(hive: hive, key: key, name: "TestKey")
    #expect(deletedValue == nil)
  }
}
