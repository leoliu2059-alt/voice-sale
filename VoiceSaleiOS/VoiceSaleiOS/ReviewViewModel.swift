import Foundation

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var input = ReviewInput()
    @Published var mode: ProcessingMode = .cloud
    @Published var jobState: JobState = .idle
    @Published var selectedTab: ReviewTab = .scorecard
    @Published var sellerSpeaker = "A"
    @Published var review: ReviewResult?
    @Published var records: [ReviewRecord] = []
    @Published var alertMessage: String?

    private let recordStore: ReviewRecordStore
    private let cloudService: CloudReviewService
    private var importedFileURL: URL?

    init(recordStore: ReviewRecordStore = LocalReviewRepository(), cloudService: CloudReviewService = CloudReviewService()) {
        self.recordStore = recordStore
        self.cloudService = cloudService
        records = (try? recordStore.loadRecords()) ?? []
        review = records.first?.result
    }

    func setImportedFile(_ url: URL) {
        input.fileName = url.lastPathComponent
        importedFileURL = url
    }

    func runDemoAnalysis(auth: SupabaseAuthStore? = nil) {
        Task {
            alertMessage = nil
            if mode == .cloud {
                await runCloudDemo(auth: auth)
            } else {
                await runLocalDemo()
            }
        }
    }

    private func runLocalDemo() async {
        jobState = .uploading
        try? await Task.sleep(for: .milliseconds(420))
        jobState = .transcribing
        try? await Task.sleep(for: .milliseconds(520))
        jobState = .analyzing
        try? await Task.sleep(for: .milliseconds(520))
        let result = MockReviewEngine.build(input: input)
        review = result
        saveRecord(result)
        selectedTab = .scorecard
        jobState = .done
    }

    private func runCloudDemo(auth: SupabaseAuthStore?) async {
        guard
            let auth,
            let userId = auth.userId,
            let accessToken = auth.accessToken
        else {
            alertMessage = "请先登录后再使用云端模式。"
            return
        }

        do {
            jobState = .uploading
            let call = try await cloudService.createCall(input: input, userId: userId, accessToken: accessToken)

            if let fileURL = importedFileURL {
                let granted = fileURL.startAccessingSecurityScopedResource()
                defer { if granted { fileURL.stopAccessingSecurityScopedResource() } }
                _ = try await cloudService.uploadAudio(callId: call.id, fileURL: fileURL, userId: userId, accessToken: accessToken)
            }

            jobState = .transcribing
            try? await Task.sleep(for: .milliseconds(420))
            jobState = .analyzing
            try? await Task.sleep(for: .milliseconds(520))

            let result = MockReviewEngine.build(input: input)
            review = result

            let record = ReviewRecord(
                createdAt: Date(),
                title: input.fileName.isEmpty ? "销售对话" : input.fileName,
                input: input,
                result: result
            )

            try await cloudService.persistReviewResult(callId: call.id, record: record, userId: userId, accessToken: accessToken)
            records.insert(record, at: 0)
            try? recordStore.saveRecords(records)
            selectedTab = .scorecard
            jobState = .done
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            jobState = .idle
        }
    }

    private func saveRecord(_ result: ReviewResult) {
        let record = ReviewRecord(
            createdAt: Date(),
            title: input.fileName.isEmpty ? "样例销售对话" : input.fileName,
            input: input,
            result: result
        )

        records.insert(record, at: 0)
        try? recordStore.saveRecords(records)
    }
}
