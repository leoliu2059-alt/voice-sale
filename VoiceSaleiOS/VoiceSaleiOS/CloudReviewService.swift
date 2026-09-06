import Foundation
import UniformTypeIdentifiers

struct CloudCall: Codable, Sendable {
    let id: String
    let title: String
    let industry: String
    let callGoal: String
    let audioPath: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case industry
        case callGoal = "call_goal"
        case audioPath = "audio_path"
        case status
    }
}

final class CloudReviewService: @unchecked Sendable {
    private let api: SupabaseREST

    init(api: SupabaseREST = SupabaseREST()) {
        self.api = api
    }

    func createCall(input: ReviewInput, userId: String, accessToken: String) async throws -> CloudCall {
        struct InsertProduct: Codable {
            let userId: String
            let name: String
            let industry: String
            let valueStatement: String

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case name
                case industry
                case valueStatement = "value_statement"
            }
        }

        struct ProductRow: Decodable {
            let id: String
        }

        let productData = try await api.insertRow(
            "products",
            row: InsertProduct(userId: userId, name: input.productName, industry: input.industry, valueStatement: input.productValue),
            accessToken: accessToken
        )
        let productId = try JSONDecoder().decode([ProductRow].self, from: productData).first?.id

        struct InsertCall: Codable {
            let userId: String
            let productId: String?
            let title: String
            let industry: String
            let callGoal: String
            let status: String

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case productId = "product_id"
                case title
                case industry
                case callGoal = "call_goal"
                case status
            }
        }

        let row = InsertCall(
            userId: userId,
            productId: productId,
            title: input.fileName.isEmpty ? "销售对话" : input.fileName,
            industry: input.industry,
            callGoal: input.callGoal,
            status: "created"
        )

        let data = try await api.insertRow("calls", row: row, accessToken: accessToken)
        let calls = try JSONDecoder().decode([CloudCall].self, from: data)
        guard let first = calls.first else { throw SupabaseRESTError.invalidResponse }
        return first
    }

    func uploadAudio(callId: String, fileURL: URL, userId: String, accessToken: String) async throws -> String {
        let filename = fileURL.lastPathComponent.isEmpty ? "\(callId).m4a" : fileURL.lastPathComponent
        let safeFilename = filename.replacingOccurrences(of: "/", with: "_")
        let objectPath = "\(userId)/\(callId)/\(safeFilename)"
        let contentType = contentTypeForFile(fileURL)

        try await api.uploadObject(bucket: "call-audio", path: objectPath, fileURL: fileURL, contentType: contentType, accessToken: accessToken)

        struct Patch: Codable {
            let audioPath: String
            let status: String
            enum CodingKeys: String, CodingKey {
                case audioPath = "audio_path"
                case status
            }
        }

        try await api.updateRow("calls", match: ["id": callId], patch: Patch(audioPath: objectPath, status: "uploaded"), accessToken: accessToken)
        return objectPath
    }

    func persistReviewResult(callId: String, record: ReviewRecord, userId: String, accessToken: String) async throws {
        struct InsertJob: Codable {
            let callId: String
            let userId: String
            let jobType: String
            let status: String

            enum CodingKeys: String, CodingKey {
                case callId = "call_id"
                case userId = "user_id"
                case jobType = "job_type"
                case status
            }
        }

        _ = try await api.insertRow(
            "analysis_jobs",
            row: [
                InsertJob(callId: callId, userId: userId, jobType: "transcription", status: "completed"),
                InsertJob(callId: callId, userId: userId, jobType: "review_analysis", status: "completed"),
            ],
            accessToken: accessToken
        )

        struct InsertTranscriptSegment: Codable {
            let callId: String
            let startMS: Int
            let endMS: Int
            let speaker: String
            let text: String
            let confidence: Double?

            enum CodingKeys: String, CodingKey {
                case callId = "call_id"
                case startMS = "start_ms"
                case endMS = "end_ms"
                case speaker
                case text
                case confidence
            }
        }

        let segments = record.result.transcript.map {
            InsertTranscriptSegment(callId: callId, startMS: $0.startMS, endMS: $0.endMS, speaker: $0.speaker, text: $0.text, confidence: $0.confidence)
        }
        if !segments.isEmpty {
            _ = try await api.insertRow("transcript_segments", row: segments, accessToken: accessToken)
        }

        struct InsertReviewResult: Codable {
            let callId: String
            let persona: Persona
            let decisiveMisses: [DecisiveMiss]
            let signals: [Signal]
            let nextCallTalktrack: NextCallTalktrack
            let fullResult: ReviewResult

            enum CodingKeys: String, CodingKey {
                case callId = "call_id"
                case persona
                case decisiveMisses = "decisive_misses"
                case signals
                case nextCallTalktrack = "next_call_talktrack"
                case fullResult = "full_result"
            }
        }

        struct ReviewResultRow: Decodable {
            let id: String
        }

        let reviewRow = InsertReviewResult(
            callId: callId,
            persona: record.result.persona,
            decisiveMisses: record.result.decisiveMisses,
            signals: record.result.signals,
            nextCallTalktrack: record.result.nextCallTalktrack,
            fullResult: record.result
        )

        let reviewData = try await api.insertRow("review_results", row: reviewRow, accessToken: accessToken)
        let insertedReview = try JSONDecoder().decode([ReviewResultRow].self, from: reviewData).first

        struct InsertEvidenceClip: Codable {
            let callId: String
            let reviewResultId: String?
            let startMS: Int
            let endMS: Int
            let quote: String
            let label: String

            enum CodingKeys: String, CodingKey {
                case callId = "call_id"
                case reviewResultId = "review_result_id"
                case startMS = "start_ms"
                case endMS = "end_ms"
                case quote
                case label
            }
        }

        let reviewResultId = insertedReview?.id
        var clips: [InsertEvidenceClip] = []

        for evidence in record.result.persona.evidenceRefs {
            clips.append(.init(callId: callId, reviewResultId: reviewResultId, startMS: evidence.startMS, endMS: evidence.endMS, quote: evidence.quote, label: "persona"))
        }

        for signal in record.result.signals {
            for evidence in signal.evidence {
                clips.append(.init(callId: callId, reviewResultId: reviewResultId, startMS: evidence.startMS, endMS: evidence.endMS, quote: evidence.quote, label: "signal:\(signal.capability)"))
            }
        }

        for miss in record.result.decisiveMisses {
            clips.append(.init(callId: callId, reviewResultId: reviewResultId, startMS: miss.startMS, endMS: miss.endMS, quote: miss.customerQuote, label: "miss:\(miss.capability)"))
        }

        if !clips.isEmpty {
            _ = try await api.insertRow("evidence_clips", row: clips, accessToken: accessToken)
        }

        struct CallPatch: Codable {
            let status: String
        }
        try await api.updateRow("calls", match: ["id": callId], patch: CallPatch(status: "completed"), accessToken: accessToken)
    }

    private func contentTypeForFile(_ url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension), let mime = type.preferredMIMEType {
            return mime
        }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a": return "audio/x-m4a"
        case "aac": return "audio/aac"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "caf": return "audio/x-caf"
        case "flac": return "audio/flac"
        case "aif", "aiff": return "audio/aiff"
        case "webm": return "audio/webm"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        default: return "application/octet-stream"
        }
    }
}
