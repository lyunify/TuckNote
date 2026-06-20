import AppKit
import XCTest
@testable import TuckNote

final class ImageStoreTests: XCTestCase {
    func testSavePNGReturnsWikiReferenceAndWritesDecodableImage() throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImageStore(baseDirectory: directory)

        let reference = try store.savePNG(makeImage())

        let filename = try XCTUnwrap(filename(from: reference))
        let identifier = try XCTUnwrap(UUID(uuidString: String(filename.dropLast(".png".count))))
        XCTAssertEqual(reference, "![[\(identifier.uuidString).png]]")
        let imageURL = directory.appending(path: "Images").appending(path: filename)
        let data = try Data(contentsOf: imageURL)
        XCTAssertNotNil(NSImage(data: data))
    }

    func testImageLoadsSavedPNGByFilename() throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImageStore(baseDirectory: directory)
        let reference = try store.savePNG(makeImage())
        let filename = try XCTUnwrap(filename(from: reference))

        let loaded = try XCTUnwrap(store.image(named: filename))

        XCTAssertEqual(loaded.size, NSSize(width: 2, height: 2))
    }

    func testImageRejectsPathTraversal() throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let outsideURL = directory.appending(path: "outside.png")
        try pngData().write(to: outsideURL)
        let store = ImageStore(baseDirectory: directory)

        XCTAssertNil(store.image(named: "../outside.png"))
        XCTAssertNil(store.image(named: outsideURL.path))
    }

    func testCleanupUsesReferencesAcrossEveryPage() throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImageStore(baseDirectory: directory)
        let firstReference = try store.savePNG(makeImage())
        let secondReference = try store.savePNG(makeImage())
        let firstFilename = try XCTUnwrap(filename(from: firstReference))
        let secondFilename = try XCTUnwrap(filename(from: secondReference))
        let firstPage = NotePage(markdown: "First \(firstReference)")
        let secondPage = NotePage(markdown: "Second \(secondReference)")
        let notebook = Notebook(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: [firstPage, secondPage],
            activePageID: firstPage.id
        )

        try store.removeUnreferencedImages(in: notebook)

        XCTAssertNotNil(store.image(named: firstFilename))
        XCTAssertNotNil(store.image(named: secondFilename))
    }

    func testCleanupRemovesOnlyUnreferencedPNGsAndIgnoresOtherFiles() throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImageStore(baseDirectory: directory)
        let referenced = try store.savePNG(makeImage())
        let unreferenced = try store.savePNG(makeImage())
        let referencedFilename = try XCTUnwrap(filename(from: referenced))
        let unreferencedFilename = try XCTUnwrap(filename(from: unreferenced))
        let imagesDirectory = directory.appending(path: "Images")
        let textURL = imagesDirectory.appending(path: "keep.txt")
        let uppercasePNGURL = imagesDirectory.appending(path: "keep.PNG")
        try Data("keep".utf8).write(to: textURL)
        try pngData().write(to: uppercasePNGURL)
        let page = NotePage(markdown: "Exact reference: \(referenced)")
        let notebook = Notebook(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: [page],
            activePageID: page.id
        )

        try store.removeUnreferencedImages(in: notebook)

        XCTAssertNotNil(store.image(named: referencedFilename))
        XCTAssertNil(store.image(named: unreferencedFilename))
        XCTAssertTrue(FileManager.default.fileExists(atPath: textURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: uppercasePNGURL.path))
    }

    private func makeImage() -> NSImage {
        NSImage(data: pngData())!
    }

    private func pngData() -> Data {
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        representation.setColor(
            NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1),
            atX: 0,
            y: 0
        )
        representation.setColor(
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
            atX: 1,
            y: 0
        )
        representation.setColor(
            NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1),
            atX: 0,
            y: 1
        )
        representation.setColor(
            NSColor(deviceRed: 1, green: 1, blue: 1, alpha: 1),
            atX: 1,
            y: 1
        )
        return representation.representation(using: .png, properties: [:])!
    }

    private func filename(from reference: String) -> String? {
        guard reference.hasPrefix("![["), reference.hasSuffix("]]"), reference.count > 5 else {
            return nil
        }
        return String(reference.dropFirst(3).dropLast(2))
    }

    private func temporaryDirectory(named testName: String) -> URL {
        let directoryName = testName.replacingOccurrences(of: "()", with: "")
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TuckNoteImageStoreTests")
            .appending(path: directoryName)
        try? FileManager.default.removeItem(at: directory)
        return directory
    }
}
