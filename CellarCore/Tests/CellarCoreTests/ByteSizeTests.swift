import Testing
@testable import CellarCore

@Suite("ByteSize")
struct ByteSizeTests {

    @Test("byteSize_parse_usesPowersOfThousand")
    func byteSize_parse_usesPowersOfThousand() {
        #expect(ByteSize.parse("(11MB)") == 11_000_000)
        #expect(ByteSize.parse("(1.2GB)") == 1_200_000_000)
        #expect(ByteSize.parse("17.3KB") == 17_300)
        #expect(ByteSize.parse("(512B)") == 512)
        #expect(ByteSize.parse("(soon)") == nil)
    }
}
