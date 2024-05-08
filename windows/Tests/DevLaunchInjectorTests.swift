import FabricSandbox

import Testing

let testConfig = """
commonProperties
  fabric.development=true
clientProperties
  java.library.path=/home/user/.gradle/caches/fabric-loom/natives/1.14.4
  org.lwjgl.librarypat=/home/user/.gradle/caches/fabric-loom/natives/1.14.4
clientArgs
  --assetIndex=1.14.4-1.14
  --assetsDir=/home/user/.gradle/caches/fabric-loom/assets
"""
struct DevLaunchInjectorTests {
  @Test func read() throws {
    let config = try DevLaunchInjector(fromString: testConfig)
    #expect(
      config.expandArgs().sorted() == [
        "--assetIndex=1.14.4-1.14", "--assetsDir=/home/user/.gradle/caches/fabric-loom/assets",
      ])
    #expect(
      config.expandProps().sorted() == [
        "-Dfabric.development=true",
        "-Djava.library.path=/home/user/.gradle/caches/fabric-loom/natives/1.14.4",
        "-Dorg.lwjgl.librarypat=/home/user/.gradle/caches/fabric-loom/natives/1.14.4",
      ])
  }
}
