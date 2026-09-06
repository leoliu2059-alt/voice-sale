import Foundation

enum MockReviewEngine {
    static func build(input: ReviewInput) -> ReviewResult {
        let productName = input.productName.isEmpty ? "家庭保障方案" : input.productName
        let productValue = input.productValue.isEmpty
            ? "用更低的年度预算覆盖家庭主要收入风险，并把理赔条件讲清楚"
            : input.productValue

        return ReviewResult(
            transcript: [
                TranscriptLine(startMS: 0, endMS: 21_000, speaker: "销售", text: "您好，我今天想跟您聊一下\(productName)，主要看看是否能帮您把保障做得更完整。", confidence: 0.94),
                TranscriptLine(startMS: 22_000, endMS: 43_000, speaker: "客户", text: "我其实之前也了解过一些，但总觉得条款太复杂，而且预算也不想太高。", confidence: 0.91),
                TranscriptLine(startMS: 44_000, endMS: 68_000, speaker: "销售", text: "这个产品性价比还是不错的，很多客户都会选这个版本，保障范围也比较全面。", confidence: 0.89),
                TranscriptLine(startMS: 69_000, endMS: 92_000, speaker: "客户", text: "我主要担心理赔的时候麻烦，另外家里支出也挺多的。", confidence: 0.92),
                TranscriptLine(startMS: 93_000, endMS: 118_000, speaker: "销售", text: "那我们可以先看一下价格，这个方案每年大概一万二，您觉得怎么样？", confidence: 0.90),
                TranscriptLine(startMS: 119_000, endMS: 146_000, speaker: "客户", text: "我再考虑一下吧，现在马上定还是有点犹豫。", confidence: 0.93),
                TranscriptLine(startMS: 147_000, endMS: 173_000, speaker: "销售", text: "可以的，那我回头把资料发您，您有问题再问我。", confidence: 0.95)
            ],
            stages: [
                StageSegment(startMS: 0, endMS: 21_000, stage: "开场"),
                StageSegment(startMS: 22_000, endMS: 68_000, stage: "探需"),
                StageSegment(startMS: 69_000, endMS: 118_000, stage: "价值呈现"),
                StageSegment(startMS: 119_000, endMS: 146_000, stage: "异议处理"),
                StageSegment(startMS: 147_000, endMS: 173_000, stage: "收尾")
            ],
            signals: [
                Signal(capability: "感知现实", verdict: "中", behavior: "能捕捉到客户提到预算与条款复杂，但没有把两个顾虑拆开确认。", evidence: [EvidenceRef(startMS: 22_000, endMS: 43_000, quote: "条款太复杂，而且预算也不想太高。")], suggestion: "先复述客户的两个顾虑，再问哪个是今天最影响决定的点。"),
                Signal(capability: "诊断问题", verdict: "弱", behavior: "客户两次表达真实顾虑后，销售都直接进入产品或价格，没有追问原因。", evidence: [EvidenceRef(startMS: 69_000, endMS: 92_000, quote: "我主要担心理赔的时候麻烦，另外家里支出也挺多的。")], suggestion: "用“您担心理赔麻烦，主要是之前听过案例，还是不确定哪些情况能赔？”继续挖。"),
                Signal(capability: "建模人性", verdict: "中", behavior: "客户偏风险规避型，真正担心的是未来出事时不确定，而不是单纯嫌贵。", evidence: [EvidenceRef(startMS: 119_000, endMS: 146_000, quote: "马上定还是有点犹豫。")], suggestion: "不要继续压成交，改用“把不确定点列出来逐个排除”的推进方式。"),
                Signal(capability: "构造价值", verdict: "中", behavior: "价值表达停留在“保障全面、性价比不错”，还没有把产品价值翻译成客户正在承受的家庭风险。", evidence: [EvidenceRef(startMS: 44_000, endMS: 68_000, quote: "保障范围也比较全面。")], suggestion: "把价值说成客户场景：这笔预算解决的是收入中断后家里现金流不断的问题。"),
                Signal(capability: "生成信任", verdict: "中", behavior: "语气平稳，但缺少对客户顾虑的复述与确认，信任感没有被进一步放大。", evidence: [EvidenceRef(startMS: 69_000, endMS: 92_000, quote: "我主要担心理赔的时候麻烦。")], suggestion: "先承认顾虑合理，再给清晰边界和处理流程。"),
                Signal(capability: "拆解风险", verdict: "弱", behavior: "客户提出“理赔麻烦”后，没有拆成材料、流程、责任范围或服务支持。", evidence: [EvidenceRef(startMS: 93_000, endMS: 118_000, quote: "那我们可以先看一下价格。")], suggestion: "先把风险拆小，再给证据：哪些情况能赔、谁协助、通常多久处理。"),
                Signal(capability: "设计决策", verdict: "弱", behavior: "客户说“再考虑”后，销售没有提供比较框架，客户只能自己消化复杂信息。", evidence: [EvidenceRef(startMS: 119_000, endMS: 146_000, quote: "我再考虑一下吧，现在马上定还是有点犹豫。")], suggestion: "给客户一个三项比较框架：预算、理赔、保障范围，并让客户先选最卡住的一项。"),
                Signal(capability: "设计交换", verdict: "中", behavior: "报价出现得较早，价值锚定不足，客户容易只比较价格。", evidence: [EvidenceRef(startMS: 93_000, endMS: 118_000, quote: "每年大概一万二，您觉得怎么样？")], suggestion: "报价前先锚定交换：\(productValue)。"),
                Signal(capability: "复盘迭代", verdict: "中", behavior: "这次最值得带到下一通的迭代点，是不要在异议未拆解前进入报价。", evidence: [EvidenceRef(startMS: 93_000, endMS: 118_000, quote: "那我们可以先看一下价格。")], suggestion: "下一通先练一个动作：客户表达顾虑后，连续追问两层再给方案。")
            ],
            decisiveMisses: [
                DecisiveMiss(startMS: 69_000, endMS: 118_000, customerQuote: "我主要担心理赔的时候麻烦，另外家里支出也挺多的。", sellerReply: "那我们可以先看一下价格，这个方案每年大概一万二。", capability: "拆解风险", whyItMatters: "客户抛出的核心异议是“理赔不确定性”，销售却切到报价，导致客户把注意力转向成本，而不是风险被解决。", betterReply: "我先不急着报价。您说理赔麻烦，我想确认一下，您更担心的是条款看不懂、材料准备麻烦，还是怕真正出险时没人协助？"),
                DecisiveMiss(startMS: 119_000, endMS: 173_000, customerQuote: "我再考虑一下吧，现在马上定还是有点犹豫。", sellerReply: "那我回头把资料发您，您有问题再问我。", capability: "设计决策", whyItMatters: "“再考虑一下”没有被拆解，销售把下一步交还给客户，等于让客户独自面对复杂决策。", betterReply: "可以，您不用现在定。我们先把要考虑的点列清楚：预算、理赔、保障范围。这里面哪一个如果弄明白，您最容易往前走？")
            ],
            persona: Persona(
                role: input.industry == "房产" ? "改善型购房客户" : "家庭责任承担者",
                budgetSensitivity: "高",
                decisionStyle: "风险规避型，先排除不确定性，再接受方案比较",
                keyPains: ["怕条款复杂", "担心理赔不顺", "家庭现金流压力"],
                objections: ["预算不想太高", "需要再考虑", "不确定理赔是否麻烦"],
                triggers: ["清晰流程", "可比较方案", "有人协助处理后续问题"],
                evidenceRefs: [
                    EvidenceRef(startMS: 22_000, endMS: 43_000, quote: "条款太复杂，而且预算也不想太高。"),
                    EvidenceRef(startMS: 69_000, endMS: 92_000, quote: "我主要担心理赔的时候麻烦。")
                ]
            ),
            nextCallTalktrack: NextCallTalktrack(
                opening: "上次您提到两个点：预算不能太高，以及理赔时怕麻烦。今天我想先把这两个问题拆清楚，不急着让您决定。",
                discoveryQuestions: [
                    "如果只看理赔，您最担心的是材料、流程，还是条款边界？",
                    "家庭预算里，您觉得每年多少以内是可以安心讨论的范围？",
                    "如果有两个方案，一个便宜但责任少，一个贵一点但关键风险覆盖更完整，您会怎么比较？"
                ],
                valuePitch: "\(productName)的价值不是“多买一份东西”，而是用可控预算换一个关键风险发生时有人负责、流程清楚的解决方案。",
                objectionHandles: [
                    "您说再考虑一下很正常，我们先把要考虑的点列出来，不让它变成一团模糊压力。",
                    "如果预算是主要点，我给您做两个版本：基础防大风险，增强版补关键缺口。"
                ],
                close: "这次我们不做复杂决定，只确认一个下一步：您更愿意先看预算版本，还是先看理赔流程说明？",
                doNotSay: ["这个产品很多人都买", "性价比很高", "您觉得这个价格怎么样"]
            )
        )
    }
}
