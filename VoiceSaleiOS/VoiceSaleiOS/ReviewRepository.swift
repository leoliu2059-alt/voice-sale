import Foundation

protocol ReviewRecordStore {
    func loadRecords() throws -> [ReviewRecord]
    func saveRecords(_ records: [ReviewRecord]) throws
}

struct LocalReviewRepository: ReviewRecordStore {
    private let fileName = "voice-sale-review-records.json"

    func loadRecords() throws -> [ReviewRecord] {
        let fileURL = try recordsFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.reviewDecoder.decode([ReviewRecord].self, from: data)
    }

    func saveRecords(_ records: [ReviewRecord]) throws {
        let fileURL = try recordsFileURL()
        let data = try JSONEncoder.reviewEncoder.encode(records)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func recordsFileURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent(fileName)
    }
}

private extension JSONEncoder {
    static var reviewEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var reviewDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
