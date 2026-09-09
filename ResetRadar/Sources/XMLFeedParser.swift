import Foundation

final class XMLFeedParser: NSObject, XMLParserDelegate {
    private var items: [FeedItem] = []
    private var current: [String: String] = [:]
    private var text = ""
    private var insideItem = false
    private var parsedSuccessfully = false
    private var recognizedFeedRoot = false

    func parse(_ data: Data) throws -> [FeedItem] {
        items = []
        current = [:]
        recognizedFeedRoot = false
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        parsedSuccessfully = parser.parse()
        guard parsedSuccessfully, recognizedFeedRoot else { throw FeedError.malformedXML }
        return items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = localName(qName ?? elementName)
        text = ""
        if element == "rss" || element == "feed" { recognizedFeedRoot = true }
        if element == "item" || element == "entry" {
            insideItem = true
            current = [:]
        }
        if insideItem, element == "link", let href = attributeDict["href"] {
            let rel = attributeDict["rel"] ?? "alternate"
            if rel == "alternate" || current["link"] == nil { current["link"] = href }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let element = localName(qName ?? elementName)
        guard insideItem else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, ["title", "description", "summary", "content", "guid", "id", "link", "pubDate", "published", "updated"].contains(element) {
            current[element] = (current[element] ?? "") + value
        }
        if element == "item" || element == "entry" {
            finishItem()
            insideItem = false
        }
        text = ""
    }

    private func finishItem() {
        let title = current["title"]?.decodedXMLText ?? "Untitled"
        let body = (current["description"] ?? current["summary"] ?? current["content"] ?? "").decodedXMLText
        let linkText = current["link"]
        let stableID = current["guid"] ?? current["id"] ?? linkText ?? "\(title)|\(current["published"] ?? current["pubDate"] ?? "")"
        let dateText = current["published"] ?? current["updated"] ?? current["pubDate"]
        items.append(FeedItem(
            id: stableID,
            title: title,
            body: body,
            url: linkText.flatMap(URL.init(string:)),
            publishedAt: dateText.flatMap(Self.parseDate)
        ))
    }

    private func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    private static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

private extension String {
    var decodedXMLText: String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
