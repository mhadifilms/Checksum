import XCTest
@testable import ChecksumKit

final class ChecksumKitTests: XCTestCase {
	func testMD5Consistency() throws {
		let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
		try "hello world".data(using: .utf8)!.write(to: temp)
		let digest = try Hasher.md5(of: temp).hexString
		XCTAssertEqual(digest, "5eb63bbbe01eeed093cb22bb8f5acdc3")
		try FileManager.default.removeItem(at: temp)
	}
}


