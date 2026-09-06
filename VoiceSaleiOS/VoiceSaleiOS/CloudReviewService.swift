import Foundation
import UniformTypeIdentifiers

struct CloudCall: Codable, Sendable {
    let id: String
    let title: String
    let industry: String
    let callGoal: String
    let audioPath: String?
    let status: String
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case industry
        case callGoal = "call_goal"
        case audioPath = "audio_path"
        case status
        case errorMessage = "error_message"
    }
}

enum CloudReviewServiceError: Error, LocalizedError {
    case processingFailed(String?)
    case missingReviewResult

    var errorDescription: String? {
        switch self {
        case let .processingFailed(message):
            return message?.isEmpty == false ? message : "云端处理失败，请稍后重试。"
        case .missingReviewResult:
            return "云端处理已结束，但尚未返回复盘结果。"
        }
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

        return objectPath
    }

    func submitProcessing(callId: String, audioPath: String, accessToken: String) async throws {
        struct Request: Codable {
            let callId: String
            let audioPath: String
        }

        _ = try await api.invokeFunction(
            "process-sales-call",
            body: Request(callId: callId, audioPath: audioPath),
            accessToken: accessToken
        )
    }

    func fetchCall(callId: String, accessToken: String) async throws -> CloudCall {
        let data = try await api.selectRows("calls", match: ["id": callId], accessToken: accessToken)
        guard let call = try JSONDecoder().decode([CloudCall].self, from: data).first else {
            throw SupabaseRESTError.invalidResponse
        }
        return call
    }

    func fetchReviewResult(callId: String, accessToken: String) async throws -> ReviewResult {
        struct ReviewResultRow: Decodable {
            let fullResult: ReviewResult

            enum CodingKeys: String, CodingKey {
                case fullResult = "full_result"
            }
        }

        let data = try await api.selectRows("review_results", match: ["call_id": callId], accessToken: accessToken)
        guard let row = try JSONDecoder().decode([ReviewResultRow].self, from: data).first else {
            throw CloudReviewServiceError.missingReviewResult
        }
        return row.fullResult
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
