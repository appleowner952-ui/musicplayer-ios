import Foundation

/// One song inside muzik.pak. Mirrors PakEntry in the Windows build.
struct PakEntry: Identifiable, Hashable {
    let id: Int
    let name: String
    let offset: Int64
    let length: Int64

    var group: String {
        if let index = name.firstIndex(of: "\\") {
            return String(name[..<index])
        }
        return "Other"
    }

    var title: String {
        let file = name.split(separator: "\\").last.map(String.init) ?? name
        if file.lowercased().hasSuffix(".mp3") {
            return String(file.dropLast(4))
        }
        return file
    }
}

enum PakError: LocalizedError {
    case invalid
    case badMagic

    var errorDescription: String? {
        switch self {
        case .invalid: return "muzik.pak bozuk veya okunamadı."
        case .badMagic: return "muzik.pak tanınmadı (başlık MUSPAK1_ değil)."
        }
    }
}

/// Reads and appends to muzik.pak using the exact same layout as the Windows app:
///
///   "MUSPAK1_" + 3 zero bytes
///   repeat until EOF:
///     int32 (little endian)  name length in bytes (UTF-8)
///     byte[]                 name, e.g. "Artist\Artist - Title.mp3"
///     int64 (little endian)  data length
///     byte[]                 mp3 data
final class PakLibrary {
    static let fileName = "muzik.pak"

    private let magic = "MUSPAK1_"
    private let headerSize = 11

    let url: URL
    private(set) var entries: [PakEntry] = []

    static var documentsURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    init(url: URL) throws {
        self.url = url
        try load()
    }

    // MARK: - Reading

    func load() throws {
        entries.removeAll()

        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let end = try handle.seekToEnd()
        guard end >= UInt64(headerSize) else { throw PakError.invalid }

        try handle.seek(toOffset: 0)
        guard let head = try handle.read(upToCount: 8),
              String(data: head, encoding: .ascii) == magic else {
            throw PakError.badMagic
        }

        try handle.seek(toOffset: UInt64(headerSize))
        var index = 0

        while true {
            let position = try handle.offset()
            if position >= end { break }

            guard let nameLengthData = try handle.read(upToCount: 4),
                  nameLengthData.count == 4 else { throw PakError.invalid }
            let nameLength = Int(Self.int32LE(nameLengthData))
            guard nameLength > 0, nameLength <= 4096 else { throw PakError.invalid }

            guard let nameData = try handle.read(upToCount: nameLength),
                  nameData.count == nameLength else { throw PakError.invalid }
            let name = String(data: nameData, encoding: .utf8) ?? ""

            guard let lengthData = try handle.read(upToCount: 8),
                  lengthData.count == 8 else { throw PakError.invalid }
            let length = Self.int64LE(lengthData)
            guard length >= 0 else { throw PakError.invalid }

            let dataOffset = try handle.offset()
            guard dataOffset + UInt64(length) <= end else { throw PakError.invalid }

            entries.append(PakEntry(id: index, name: name, offset: Int64(dataOffset), length: length))
            index += 1

            try handle.seek(toOffset: dataOffset + UInt64(length))
        }
    }

    func data(for entry: PakEntry) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(entry.offset))
        guard let data = try handle.read(upToCount: Int(entry.length)),
              data.count == Int(entry.length) else {
            throw PakError.invalid
        }
        return data
    }

    // MARK: - Writing

    /// Copies an .mp3 into the package (streamed, so a large file never sits fully in memory).
    func add(sourceURL: URL, fileName: String) throws -> PakEntry {
        let manager = FileManager.default

        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }

        if !manager.fileExists(atPath: url.path) {
            manager.createFile(atPath: url.path, contents: nil)
            let headerHandle = try FileHandle(forWritingTo: url)
            defer { try? headerHandle.close() }
            var header = Data(magic.utf8)
            header.append(contentsOf: [0, 0, 0])
            try headerHandle.write(contentsOf: header)
        }

        let name = uniqueName("Added\\" + fileName)
        let size = ((try? manager.attributesOfItem(atPath: sourceURL.path))?[.size] as? NSNumber)?.int64Value ?? 0

        let writeHandle = try FileHandle(forWritingTo: url)
        defer { try? writeHandle.close() }
        try writeHandle.seekToEnd()

        let nameBytes = Data(name.utf8)
        var record = Data(Self.leBytes32(Int32(nameBytes.count)))
        record.append(nameBytes)
        record.append(contentsOf: Self.leBytes64(size))
        try writeHandle.write(contentsOf: record)

        let dataOffset = try writeHandle.offset()

        let readHandle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? readHandle.close() }
        while let chunk = try readHandle.read(upToCount: 1 << 20), !chunk.isEmpty {
            try writeHandle.write(contentsOf: chunk)
        }

        let entry = PakEntry(id: entries.count, name: name, offset: Int64(dataOffset), length: size)
        entries.append(entry)
        return entry
    }

    private func uniqueName(_ name: String) -> String {
        let existing = Set(entries.map { $0.name.lowercased() })
        if !existing.contains(name.lowercased()) { return name }

        let parts = name.split(separator: "\\", omittingEmptySubsequences: false)
        let directory = parts.dropLast()
        let file = parts.last.map(String.init) ?? name

        let base: String
        let ext: String
        if let dot = file.lastIndex(of: ".") {
            base = String(file[..<dot])
            ext = String(file[dot...])
        } else {
            base = file
            ext = ""
        }

        var counter = 2
        while true {
            let candidateFile = "\(base) (\(counter))\(ext)"
            let candidate = (directory.map(String.init) + [candidateFile]).joined(separator: "\\")
            if !existing.contains(candidate.lowercased()) { return candidate }
            counter += 1
        }
    }

    // MARK: - Little endian helpers

    private static func int32LE(_ data: Data) -> Int32 {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { return 0 }
        let value = UInt32(bytes[0])
            | (UInt32(bytes[1]) << 8)
            | (UInt32(bytes[2]) << 16)
            | (UInt32(bytes[3]) << 24)
        return Int32(bitPattern: value)
    }

    private static func int64LE(_ data: Data) -> Int64 {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { return 0 }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(bytes[index]) << (8 * UInt64(index))
        }
        return Int64(bitPattern: value)
    }

    private static func leBytes32(_ value: Int32) -> [UInt8] {
        let unsigned = UInt32(bitPattern: value)
        return [
            UInt8(unsigned & 0xff),
            UInt8((unsigned >> 8) & 0xff),
            UInt8((unsigned >> 16) & 0xff),
            UInt8((unsigned >> 24) & 0xff)
        ]
    }

    private static func leBytes64(_ value: Int64) -> [UInt8] {
        let unsigned = UInt64(bitPattern: value)
        return (0..<8).map { UInt8((unsigned >> (8 * UInt64($0))) & 0xff) }
    }
}
