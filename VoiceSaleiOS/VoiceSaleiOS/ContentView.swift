import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ReviewViewModel()
    @EnvironmentObject private var auth: SupabaseAuthStore

    var body: some View {
        TabView {
            HomeView(viewModel: viewModel)
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            RecordsView(viewModel: viewModel)
                .tabItem {
                    Label("复盘记录", systemImage: "list.bullet.rectangle")
                }

            ProfileView(viewModel: viewModel)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(AppTheme.green)
        .sheet(isPresented: $auth.isPasswordResetPresented) {
            ResetPasswordSheetView()
                .environmentObject(auth)
        }
    }
}

private struct HomeView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var isImportingAudio = false
    @State private var showingAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    HomeHeader(viewModel: viewModel)
                    StartReviewCard(viewModel: viewModel, isImportingAudio: $isImportingAudio)
                    ProcessingCard(viewModel: viewModel)
                    GoalCard(viewModel: viewModel)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: viewModel.alertMessage) { _, newValue in
            showingAlert = (newValue != nil)
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("好") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .fileImporter(
            isPresented: $isImportingAudio,
            allowedContentTypes: SupportedAudioFile.contentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let firstURL = urls.first {
                viewModel.setImportedFile(firstURL)
            }
        }
    }
}

private enum SupportedAudioFile {
    static let displayText = "支持 M4A、MP3、WAV、AAC、CAF、MP4/MOV"

    static let contentTypes: [UTType] = [
        .audio,
        .movie,
        .mpeg4Movie,
        .quickTimeMovie,
        type("m4a", fallback: .audio),
        type("mp3", fallback: .audio),
        type("wav", fallback: .audio),
        type("aac", fallback: .audio),
        type("caf", fallback: .audio),
        type("flac", fallback: .audio),
        type("aiff", fallback: .audio),
    ]

    private static func type(_ extensionName: String, fallback: UTType) -> UTType {
        UTType(filenameExtension: extensionName) ?? fallback
    }
}

private struct RecordsView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject private var auth: SupabaseAuthStore
    @State private var showingLoginSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                VStack(spacing: 14) {
                    if viewModel.records.isEmpty {
                        EmptyReviewView {
                            if viewModel.mode == .cloud, !auth.isSignedIn {
                                showingLoginSheet = true
                            } else {
                                viewModel.runDemoAnalysis(auth: auth)
                            }
                        }
                    } else {
                        ReviewRecordList(records: viewModel.records)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
                }
            }
            .navigationTitle("复盘记录")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingLoginSheet) {
            LoginSheetView()
                .environmentObject(auth)
        }
    }
}

private struct ReviewRecordList: View {
    let records: [ReviewRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近复盘")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(records) { record in
                NavigationLink {
                    ReviewDetailView(record: record)
                } label: {
                    ReviewRecordRow(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ReviewRecordRow: View {
    let record: ReviewRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.green)
                .frame(width: 44, height: 44)
                .background(AppTheme.greenSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(record.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text("\(record.input.industry) · \(record.result.decisiveMisses.count) 个决定性失分 · \(record.result.signals.count) 个维度")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
        }
        .panelCard()
    }
}

private struct ReviewDetailView: View {
    let record: ReviewRecord

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    ReviewRecordHeader(record: record)
                    ResultSwitcher(review: record.result)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        }
        .navigationTitle("复盘详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject private var auth: SupabaseAuthStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                VStack(spacing: 14) {
                    AccountCard(email: auth.userEmail ?? "未登录") {
                        Task { await auth.signOut() }
                    }
                    ProductSettingsCard(viewModel: viewModel)
                    ProviderSettingsCard(viewModel: viewModel)
                    SpeakerSettingsCard(viewModel: viewModel)
                    PrivacyCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AccountCard: View {
    let email: String
    let signOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("账号", systemImage: "person.crop.circle")
                .font(.headline)
            HStack {
                Text(email)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
            }
            Button(role: .destructive, action: signOut) {
                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .panelCard()
    }
}

private struct HomeHeader: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.green)
                .frame(width: 44, height: 44)
                .background(AppTheme.greenSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("语销镜")
                    .font(.title2.weight(.black))
                Text(viewModel.input.productName)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct StartReviewCard: View {
    @ObservedObject var viewModel: ReviewViewModel
    @Binding var isImportingAudio: Bool
    @EnvironmentObject private var auth: SupabaseAuthStore
    @State private var showingLoginSheet = false

    var body: some View {
        VStack(spacing: 14) {
            Button {
                isImportingAudio = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.green)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.greenSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.input.fileName.isEmpty ? "上传销售对话" : viewModel.input.fileName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(SupportedAudioFile.displayText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button {
                if viewModel.mode == .cloud, !auth.isSignedIn {
                    showingLoginSheet = true
                } else {
                    viewModel.runDemoAnalysis(auth: auth)
                }
            } label: {
                Label("生成复盘评分卡", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.green)
        }
        .panelCard()
        .sheet(isPresented: $showingLoginSheet) {
            LoginSheetView()
                .environmentObject(auth)
        }
    }
}

private struct GoalCard: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldRow(title: "行业", text: $viewModel.input.industry)
            FieldRow(title: "通话目标", text: $viewModel.input.callGoal)
        }
        .panelCard()
    }
}

private struct ProcessingCard: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.jobState.rawValue)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(Int(viewModel.jobState.progress * 100))%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.green)
            }
            ProgressView(value: viewModel.jobState.progress)
                .tint(AppTheme.green)
        }
        .panelCard()
    }
}

private struct ReviewRecordHeader: View {
    let record: ReviewRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.headline)
                    Text("\(record.input.industry) · \(record.input.callGoal)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Text("已完成")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.greenSoft)
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                SummaryTile(title: "决定性失分", value: "\(record.result.decisiveMisses.count) 个")
                SummaryTile(title: "能力信号", value: "\(record.result.signals.count) 项")
                SummaryTile(title: "客户预算", value: record.result.persona.budgetSensitivity)
            }
        }
        .panelCard()
    }
}

private struct ResultSwitcher: View {
    @State private var selectedTab: ReviewTab = .scorecard
    let review: ReviewResult

    var body: some View {
        VStack(spacing: 12) {
            Picker("复盘视图", selection: $selectedTab) {
                ForEach(ReviewTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            PersonaSummary(review: review)

            switch selectedTab {
            case .scorecard:
                ScorecardView(review: review)
            case .timeline:
                TimelineView(review: review)
            case .talktrack:
                TalktrackView(review: review)
            }
        }
    }
}

private struct ProductSettingsCard: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("我的产品", systemImage: "briefcase")
                .font(.headline)
            FieldRow(title: "产品名称", text: $viewModel.input.productName)
            VStack(alignment: .leading, spacing: 8) {
                Text("核心价值")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                TextEditor(text: $viewModel.input.productValue)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.black.opacity(0.10), lineWidth: 1)
                    )
            }
        }
        .panelCard()
    }
}

private struct ProviderSettingsCard: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("处理方式", systemImage: "lock.shield")
                .font(.headline)
            Picker("处理模式", selection: $viewModel.mode) {
                ForEach(ProcessingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .panelCard()
    }
}

private struct SpeakerSettingsCard: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("说话人", systemImage: "person.2.wave.2")
                .font(.headline)
            HStack {
                Text("销售说话人")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("销售说话人", selection: $viewModel.sellerSpeaker) {
                    Text("A").tag("A")
                    Text("B").tag("B")
                }
                .pickerStyle(.segmented)
                .frame(width: 112)
            }
        }
        .panelCard()
    }
}

private struct PrivacyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("隐私与数据", systemImage: "checkmark.shield")
                .font(.headline)
            Toggle("保留原始转写", isOn: .constant(true))
            Toggle("保留证据片段", isOn: .constant(true))
            Toggle("生成下一通话术", isOn: .constant(true))
        }
        .panelCard()
    }
}

private struct SettingLine: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }
}

private struct EmptyReviewView: View {
    let runDemo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppTheme.green)
            Text("先跑通一条销售复盘")
                .font(.title3.weight(.bold))
            Text("当前版本用样例引擎模拟长音频转写、阶段切分、能力诊断、决定性失分点、下一通话术的完整链路。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
            Button("查看样例结果", action: runDemo)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.green)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .panelCard()
    }
}

private struct PersonaSummary: View {
    let review: ReviewResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("用户画像", systemImage: "person.text.rectangle")
                .font(.headline)
            HStack(spacing: 10) {
                SummaryTile(title: "角色", value: review.persona.role)
                SummaryTile(title: "预算", value: review.persona.budgetSensitivity)
            }
            Text(review.persona.decisionStyle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            TagWrap(tags: review.persona.keyPains + review.persona.triggers)
            ForEach(review.persona.evidenceRefs) { evidence in
                Text("\(timeText(evidence.startMS)) · \(evidence.quote)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .panelCard()
    }
}

private struct ScorecardView: View {
    let review: ReviewResult

    var body: some View {
        VStack(spacing: 12) {
            ForEach(review.decisiveMisses) { miss in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(timeText(miss.startMS))
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.green)
                        Spacer()
                        Text(miss.capability)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.greenSoft)
                            .clipShape(Capsule())
                    }
                    QuoteBlock(title: "客户", text: miss.customerQuote)
                    Text("销售：\(miss.sellerReply)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                    Text(miss.whyItMatters)
                        .font(.subheadline)
                        .lineSpacing(3)
                    Text(miss.betterReply)
                        .font(.subheadline.weight(.semibold))
                        .lineSpacing(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.greenSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .panelCard()
            }

            ForEach(review.signals) { signal in
                SignalRow(signal: signal)
            }
        }
    }
}

private struct TimelineView: View {
    let review: ReviewResult

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(review.stages) { stage in
                        Text(stage.stage)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.softPanel)
                            .clipShape(Capsule())
                    }
                }
            }

            ForEach(review.transcript) { line in
                HStack(alignment: .top, spacing: 12) {
                    Text(timeText(line.startMS))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.green)
                        .frame(width: 48, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(line.speaker)
                            .font(.subheadline.weight(.bold))
                        Text(line.text)
                            .font(.subheadline)
                            .lineSpacing(3)
                        Text("置信度 \(Int(line.confidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .panelCard()
            }
        }
    }
}

private struct TalktrackView: View {
    let review: ReviewResult

    var body: some View {
        VStack(spacing: 12) {
            ScriptSection(title: "下一通开场", lines: [review.nextCallTalktrack.opening])
            ScriptSection(title: "探需问题", lines: review.nextCallTalktrack.discoveryQuestions)
            ScriptSection(title: "价值表达", lines: [review.nextCallTalktrack.valuePitch])
            ScriptSection(title: "异议处理", lines: review.nextCallTalktrack.objectionHandles)
            ScriptSection(title: "收尾推进", lines: [review.nextCallTalktrack.close])

            VStack(alignment: .leading, spacing: 10) {
                Label("不要这样说", systemImage: "hand.raised")
                    .font(.headline)
                TagWrap(tags: review.nextCallTalktrack.doNotSay)
            }
            .panelCard()
        }
    }
}

private struct FieldRow: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.softPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TagWrap: View {
    let tags: [String]

    var body: some View {
        FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.softPanel)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct QuoteBlock: View {
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(AppTheme.green)
                .frame(width: 3)
            Text("\(title)：\(text)")
                .font(.subheadline.weight(.semibold))
                .lineSpacing(3)
        }
    }
}

private struct SignalRow: View {
    let signal: Signal

    var verdictColor: Color {
        switch signal.verdict {
        case "强": return AppTheme.green
        case "中": return AppTheme.warning
        default: return AppTheme.danger
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(signal.verdict)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(verdictColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(signal.capability)
                    .font(.headline)
                Text(signal.behavior)
                    .font(.subheadline)
                    .lineSpacing(3)
                if let evidence = signal.evidence.first {
                    Text(evidence.quote)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Text(signal.suggestion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.green)
                    .padding(.top, 2)
            }
        }
        .panelCard()
    }
}

private struct ScriptSection: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.softPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .panelCard()
    }
}

private struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? 320, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            if alignment == .center {
                x += (bounds.width - row.width) / 2
            } else if alignment == .trailing {
                x += bounds.width - row.width
            }

            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var current = FlowRow()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if current.width + size.width + spacing > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = FlowRow()
            }
            current.items.append(FlowItem(subview: subview, size: size))
            current.width += size.width + (current.items.count > 1 ? spacing : 0)
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct FlowRow {
        var items: [FlowItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private struct FlowItem {
        let subview: LayoutSubview
        let size: CGSize
    }
}
