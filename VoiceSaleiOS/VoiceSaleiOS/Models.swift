import Foundation

enum ProcessingMode: String, CaseIterable, Codable, Identifiable {
    case cloud = "云端"
    case privateDeploy = "本地"

    var id: String { rawValue }
}

enum JobState: String {
    case idle = "等待开始"
    case uploading = "切片上传"
    case transcribing = "语音转写"
    case analyzing = "结构诊断"
    case done = "复盘完成"

    var progress: Double {
        switch self {
        case .idle: return 0
        case .uploading: return 0.28
        case .transcribing: return 0.62
        case .analyzing: return 0.84
        case .done: return 1
        }
    }
}

enum ReviewTab: String, CaseIterable, Identifiable {
    case scorecard = "评分卡"
    case timeline = "时间轴"
    case talktrack = "下一通"

    var id: String { rawValue }
}

struct ReviewInput: Codable {
    var industry = "保险"
    var callGoal = "促成下一次方案沟通"
    var productName = "家庭收入保障方案"
    var productValue = "用可控预算覆盖家庭主要收入风险，并用清晰理赔流程降低不确定性"
    var fileName = ""
}

struct TranscriptLine: Codable, Identifiable {
    var id = UUID()
    let startMS: Int
    let endMS: Int
    let speaker: String
    let text: String
    let confidence: Double
}

struct StageSegment: Codable, Identifiable {
    var id = UUID()
    let startMS: Int
    let endMS: Int
    let stage: String
}

struct EvidenceRef: Codable, Identifiable {
    var id = UUID()
    let startMS: Int
    let endMS: Int
    let quote: String
}

struct Signal: Codable, Identifiable {
    var id = UUID()
    let capability: String
    let verdict: String
    let behavior: String
    let evidence: [EvidenceRef]
    let suggestion: String
}

struct DecisiveMiss: Codable, Identifiable {
    var id = UUID()
    let startMS: Int
    let endMS: Int
    let customerQuote: String
    let sellerReply: String
    let capability: String
    let whyItMatters: String
    let betterReply: String
}

struct Persona: Codable {
    let role: String
    let budgetSensitivity: String
    let decisionStyle: String
    let keyPains: [String]
    let objections: [String]
    let triggers: [String]
    let evidenceRefs: [EvidenceRef]
}

struct NextCallTalktrack: Codable {
    let opening: String
    let discoveryQuestions: [String]
    let valuePitch: String
    let objectionHandles: [String]
    let close: String
    let doNotSay: [String]
}

struct ReviewResult: Codable {
    let transcript: [TranscriptLine]
    let stages: [StageSegment]
    let signals: [Signal]
    let decisiveMisses: [DecisiveMiss]
    let persona: Persona
    let nextCallTalktrack: NextCallTalktrack
}

struct ReviewRecord: Codable, Identifiable {
    var id = UUID()
    let createdAt: Date
    let title: String
    let input: ReviewInput
    let result: ReviewResult
}
