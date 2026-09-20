import AppKit

/// Source positions keep literal stars, escaped text and code out of emphasis styling.
struct MarkdownEmphasis {
    struct Run {
        let range: NSRange
        let intent: InlinePresentationIntent
    }

    let runs: [Run]
    let markerRanges: [NSRange]

    init(_ source: String) {
        guard let parsed = try? AttributedString(markdown: source, options: .init(appliesSourcePositionAttributes: true)) else {
            runs = []
            markerRanges = []
            return
        }
        let text = source as NSString
        var represented = IndexSet()
        var emphasis: [Run] = []
        for run in parsed.runs {
            guard let position = run.markdownSourcePosition,
                  let range = Range(position, in: source) else { continue }
            let sourceRange = NSRange(range, in: source)
            represented.insert(integersIn: sourceRange.location..<NSMaxRange(sourceRange))
            if let intent = run.inlinePresentationIntent,
               !intent.contains(.code),
               !intent.intersection([.stronglyEmphasized, .emphasized]).isEmpty {
                emphasis.append(Run(range: sourceRange, intent: intent))
            }
        }
        runs = emphasis
        var markers = IndexSet()
        for run in emphasis {
            for (start, step) in [(run.range.location - 1, -1), (NSMaxRange(run.range), 1)] {
                var position = start
                while position >= 0, position < text.length,
                      !represented.contains(position), [42, 95].contains(text.character(at: position)) {
                    markers.insert(position)
                    position += step
                }
            }
        }
        markerRanges = markers.rangeView.map { NSRange(location: $0.lowerBound, length: $0.count) }
    }

    @MainActor
    func hideMarkers(in editor: NSTextView) {
        guard !editor.hasMarkedText(), let storage = editor.textStorage else { return }
        storage.beginEditing()
        for range in markerRanges where NSMaxRange(range) <= storage.length {
            storage.addAttributes([.font: NSFont.systemFont(ofSize: 0.1), .kern: -0.1, .foregroundColor: NSColor.clear], range: range)
        }
        storage.endEditing()
    }

    func removingStyle(in source: NSString, selection: NSRange, width: Int) -> MarkdownSelectionEdit? {
        let intent: InlinePresentationIntent = width == 2 ? .stronglyEmphasized : .emphasized
        var contents: [NSRange] = []
        for run in runs where run.intent.contains(intent) {
            if let last = contents.last, run.range.location >= NSMaxRange(last) {
                let gap = NSRange(location: NSMaxRange(last), length: run.range.location - NSMaxRange(last))
                let gapText = source.substring(with: gap)
                if gapText.allSatisfy({ $0 == "*" || $0 == "_" }) {
                    contents[contents.count - 1] = NSUnionRange(last, run.range)
                    continue
                }
            }
            contents.append(run.range)
        }
        for content in contents {
            guard content.location >= width, NSMaxRange(content) + width <= source.length else { continue }
            let left = NSRange(location: content.location - width, length: width)
            let right = NSRange(location: NSMaxRange(content), length: width)
            let delimiter = source.substring(with: left)
            guard delimiter == String(repeating: "*", count: width) || delimiter == String(repeating: "_", count: width),
                  delimiter == source.substring(with: right),
                  let leftMarkers = markerRanges.first(where: { NSIntersectionRange($0, left) == left }),
                  let rightMarkers = markerRanges.first(where: { NSIntersectionRange($0, right) == right }) else { continue }
            let token = NSUnionRange(leftMarkers, rightMarkers)
            guard selection.location >= token.location, NSMaxRange(selection) <= NSMaxRange(token) else { continue }
            func mapped(_ position: Int) -> Int {
                position - min(width, max(0, position - left.location)) - min(width, max(0, position - right.location))
            }
            let start = mapped(selection.location)
            return MarkdownSelectionEdit(range: NSUnionRange(left, right), replacement: source.substring(with: content),
                                         selectedRange: NSRange(location: start, length: mapped(NSMaxRange(selection)) - start))
        }
        return nil
    }
}
