import AppKit
import Foundation

enum ImageStoreError: Error {
    case pngEncodingFailed
}

struct ImageStore {
    let imagesDirectory: URL
    private let fileManager: FileManager

    init(baseDirectory: URL, fileManager: FileManager = .default) {
        imagesDirectory = baseDirectory.appending(path: "Images", directoryHint: .isDirectory)
        self.fileManager = fileManager
    }

    func savePNG(_ image: NSImage) throws -> String {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw ImageStoreError.pngEncodingFailed
        }

        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).png"
        try pngData.write(to: imagesDirectory.appending(path: filename), options: .atomic)
        return "![[\(filename)]]"
    }

    func image(named filename: String) -> NSImage? {
        guard isSafeFilename(filename) else { return nil }
        return NSImage(contentsOf: imagesDirectory.appending(path: filename))
    }

    func removeUnreferencedImages(in notebook: Notebook) throws {
        guard fileManager.fileExists(atPath: imagesDirectory.path) else { return }

        let referencedFilenames = Set(notebook.pages.flatMap { referencedPNGs(in: $0.markdown) })
        let files = try fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for file in files where file.pathExtension == "png" {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true, !referencedFilenames.contains(file.lastPathComponent) else {
                continue
            }
            try fileManager.removeItem(at: file)
        }
    }

    private func isSafeFilename(_ filename: String) -> Bool {
        guard !filename.isEmpty, !filename.contains("\\") else { return false }
        return URL(fileURLWithPath: filename).lastPathComponent == filename
    }

    private func referencedPNGs(in markdown: String) -> [String] {
        let pattern = #"!\[\[([^\]]+\.png)\]\]"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)

        return expression.matches(in: markdown, range: range).compactMap { match in
            guard
                match.numberOfRanges > 1,
                let filenameRange = Range(match.range(at: 1), in: markdown)
            else {
                return nil
            }
            return String(markdown[filenameRange])
        }
    }
}
