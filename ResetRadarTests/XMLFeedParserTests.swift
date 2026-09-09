import XCTest
@testable import ResetRadar

final class XMLFeedParserTests: XCTestCase {
    func testParsesRSSAndDecodesMarkup() throws {
        let xml = """
        <?xml version="1.0"?><rss><channel><item><guid>x-1</guid><title>Reset &amp; limits</title><link>https://example.com/1</link><pubDate>Wed, 09 Sep 2026 06:30:00 +0000</pubDate><description><![CDATA[<b>Codex</b> reset tomorrow]]></description></item></channel></rss>
        """
        let items = try XMLFeedParser().parse(Data(xml.utf8))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, "x-1")
        XCTAssertEqual(items[0].title, "Reset & limits")
        XCTAssertEqual(items[0].body, "Codex reset tomorrow")
    }

    func testParsesAtomNamespaceAndHref() throws {
        let xml = """
        <?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><entry><id>a-1</id><title>Codex reset</title><link rel="alternate" href="https://example.com/a"/><updated>2026-09-09T06:30:00Z</updated><summary>All users</summary></entry></feed>
        """
        let item = try XCTUnwrap(XMLFeedParser().parse(Data(xml.utf8)).first)
        XCTAssertEqual(item.id, "a-1")
        XCTAssertEqual(item.url?.absoluteString, "https://example.com/a")
        XCTAssertNotNil(item.publishedAt)
    }

    func testRejectsHTMLLoginPage() {
        let html = "<html><body><form>Sign in</form></body></html>"
        XCTAssertThrowsError(try XMLFeedParser().parse(Data(html.utf8)))
    }
}
