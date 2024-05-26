import Testing
import WindowsUtils

struct ChecksumTest {
  @Test func md5() throws {
    #expect(try Checksum.hex("", .md5) == "d41d8cd98f00b204e9800998ecf8427e")
    #expect(try Checksum.hex("hello", .md5) == "5d41402abc4b2a76b9719d911017c592")
    #expect(try Checksum.hex("Hello World!", .md5) == "ed076287532e86365e841e92bfc50d8c")
  }

  @Test func sha1() throws {
    #expect(try Checksum.hex("", .sha1) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    #expect(try Checksum.hex("hello", .sha1) == "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    #expect(try Checksum.hex("Hello World!", .sha1) == "2ef7bde608ce5404e97d5f042f95f89f1c232871")
  }

  @Test func sha256() throws {
    #expect(try Checksum.hex("", .sha256) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    #expect(try Checksum.hex("hello", .sha256) == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    #expect(try Checksum.hex("Hello World!", .sha256) == "7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069")
  }
}
