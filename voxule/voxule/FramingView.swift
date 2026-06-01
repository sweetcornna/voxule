import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 装裱视图 —— 给录音选锁、选收件人、定标题，确认后埋下。
struct FramingView: View {
    let recording: RecordingResult
    /// 端侧代写标题服务（C5）。默认真实现；预览/测试可注入 Fake。
    let intelligence: any IntelligenceServicing
    /// 埋下成功后回调，用于关掉整个录音流程。
    let onBuried: () -> Void

    init(
        recording: RecordingResult,
        intelligence: any IntelligenceServicing = IntelligenceService(),
        onBuried: @escaping () -> Void
    ) {
        self.recording = recording
        self.intelligence = intelligence
        self.onBuried = onBuried
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var lockKind: Lock.Kind = .mood
    @State private var recipient: Recipient = .me
    /// 时间锁选定的日期，默认一周后。
    @State private var dateLockTarget = Date().addingTimeInterval(7 * 24 * 3600)
    /// 选「给声音圈」时锁定的圈 id。recipient 切回「自己」时清空。
    @State private var selectedCircleID: UUID?
    @State private var saveFailed = false
    /// 「埋下」后短暂停留 0.7s 的盖章仪式 —— 让落地的瞬间有「装裱完成」的实感。
    @State private var isBurying = false
    /// 代写标题进行中 —— 防重复点 + 给按钮一个 inflight 态。
    @State private var isDrafting = false

    // MARK: - 地点锁选点状态（C1）
    /// 地点锁选定坐标。默认上海市中心，用户移动地图微调。
    @State private var placeCoordinate = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
    @State private var placeName = ""
    @State private var placeRadius: Double = 100
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(durationString)
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(VoxlueColor.graphite)
                } label: {
                    Text("时长")
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.ink)
                }
                WaveformView(samples: recording.waveform, tint: VoxlueColor.ink)
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                sectionHeader("这一张")
            }

            Section {
                TextField("给这张声音起个名", text: $title)
                    .font(VoxlueTypography.serifBody)
                Button("让冲洗师代写", systemImage: "wand.and.stars") {
                    Task { await draftTitle() }
                }
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.vermillion)
                .disabled(isDrafting)
            } header: {
                sectionHeader("标题")
            }

            Section {
                // Picker / DatePicker 沿用 App 级 tint —— RootTabView 已设 vermillion，
                // 这里不重复显式声明，与本 PR 其他 Form 屏保持一致。
                Picker("锁", selection: $lockKind) {
                    Text("地点锁").tag(Lock.Kind.place)
                    Text("时间锁").tag(Lock.Kind.date)
                    Text("情绪锁").tag(Lock.Kind.mood)
                }
                .pickerStyle(.segmented)
                if lockKind == .date {
                    DatePicker("到这天显影", selection: $dateLockTarget,
                               in: Date()..., displayedComponents: [.date])
                        .font(VoxlueTypography.serifBody)
                }
                if lockKind == .place {
                    placePicker
                }
                VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
                    Text(lockHintTitle)
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.ink)
                    Text(lockHintExample)
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.graphite)
                        .padding(.leading, VoxlueSpacing.md)
                }

                // 让用户在按「埋下」之前，先看到落地后会盖上的朱章 ——
                // 隐喻才读得通：装裱 → 盖章 → 入库。
                HStack(spacing: VoxlueSpacing.md) {
                    SealStamp(.buried)
                    MarginNote("埋下后会盖上这个章")
                    Spacer(minLength: 0)
                }
                .padding(.vertical, VoxlueSpacing.xs)
            } header: {
                sectionHeader("上一把锁")
            }

            Section {
                Picker("收件人", selection: $recipient) {
                    Text("自己").tag(Recipient.me)
                    Text("声音圈").tag(Recipient.circle)
                }
                Text("收件人埋下时定死，之后不可改。")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.graphite)

                if recipient == .circle {
                    CirclePickerView(selectedCircleID: $selectedCircleID)
                }
            } header: {
                sectionHeader("给谁")
            }
        }
        .scrollContentBackground(.hidden)
        .background(VoxlueColor.paper.ignoresSafeArea())
        .overlay {
            // 0.7s 的盖章仪式 —— 表单变暗、纸卡居中浮上、朱章自带 spring 落定。
            // 数据已先于此 overlay 写库，所以 onBuried 怎么回调都不会丢数据。
            if isBurying {
                ZStack {
                    VoxlueColor.paper
                        .opacity(0.92)
                        .ignoresSafeArea()
                    PaperCard {
                        VStack(spacing: VoxlueSpacing.md) {
                            SealStamp(.buried)
                            MarginNote("一段声音，已经埋下。")
                        }
                    }
                    .padding(.horizontal, VoxlueSpacing.xl)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isBurying)
        .navigationTitle("装裱")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: recipient) { _, new in
            // 切回「自己」清掉之前选好的圈，避免误归属。
            if new == .me { selectedCircleID = nil }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("埋下") { bury() }
                    .disabled(recipient == .circle && selectedCircleID == nil)
                    .font(VoxlueTypography.serifBody)
                    .foregroundStyle(VoxlueColor.vermillion)
            }
        }
        .alert("没能定影", isPresented: $saveFailed) {
            Button("好") {}
        } message: {
            Text("写入失败，请再试一次。")
        }
    }

    /// 思源宋小标题 —— Form 默认 section header 是大写英文风，与设计语言冲突。
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(VoxlueTypography.caption)
            .foregroundStyle(VoxlueColor.graphite)
            .textCase(nil)
    }

    private var durationString: String {
        let total = Int(recording.duration)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// 第一行：这把锁的作用 —— 用户看一眼就知道「它什么时候会响」。
    private var lockHintTitle: String {
        switch lockKind {
        case .place: "地点锁：走到某个地方时，它会自己显影。"
        case .date: "时间锁：到选定那天才浮现。"
        case .mood: "情绪锁：voxlue 觉得合适时把它送来。"
        }
    }

    /// 第二行：一个具体例子 —— 抽象规则配场景，用户立刻有画面感。
    private var lockHintExample: String {
        switch lockKind {
        case .place: "像在故宫门口录一句「奶奶，我又来这了」。"
        case .date: "像给一年后的自己留一段话。"
        case .mood: "像在某个安静的晚上，外婆的口头禅突然浮现。"
        }
    }

    /// 地点锁选点 —— 移动地图把中心朱红针对准要解锁的地方，配地名与范围（C1）。
    private var placePicker: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            TextField("这个地方叫什么", text: $placeName)
                .font(VoxlueTypography.serifBody)
            ZStack {
                Map(position: $mapPosition)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onMapCameraChange(frequency: .onEnd) { context in
                        // 地图中心即所选坐标。
                        placeCoordinate = context.region.center
                    }
                // 固定在中心的朱红针 —— 不拦截手势，地图照常拖动。
                Image(systemName: "mappin")
                    .font(.title2)
                    .foregroundStyle(VoxlueColor.vermillion)
                    .allowsHitTesting(false)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            HStack {
                Text("范围")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.graphite)
                Slider(value: $placeRadius, in: 50...500, step: 10)
                Text("\(Int(placeRadius))m")
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.graphite)
            }
            Text("移动地图，把朱红针对准要解锁的地方。")
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
    }

    /// 端侧模型代写标题（C5）—— 调真实 IntelligenceService；端上模型不可用（模拟器/旧机/
    /// 离线）时回退到一组诗意占位，绝不空着。
    private func draftTitle() async {
        isDrafting = true
        defer { isDrafting = false }
        let drafted = await intelligence.draftTitle(forTranscriptHint: draftHint)
        title = drafted ?? offlineTitlePool.randomElement() ?? "未命名"
    }

    /// 给端侧模型的关键词提示 —— 无语音转写，用已有的标题草稿 + 锁语境拼一个粗提示。
    private var draftHint: String {
        var parts: [String] = []
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { parts.append(trimmed) }
        switch lockKind {
        case .place: parts.append(placeName.isEmpty ? "某个地方" : placeName)
        case .date: parts.append("留给未来")
        case .mood: parts.append("安静的时刻")
        }
        parts.append("一段环境声")
        return parts.joined(separator: " ")
    }

    /// 端上模型不可用时的离线兜底标题池。
    private let offlineTitlePool = ["未命名的雨", "某个安静的下午", "留给以后的声音", "一段没说完的话"]

    /// 由 lockKind 与表单状态组装出最终的 Lock。
    private func makeLock() -> Lock {
        switch lockKind {
        case .place:
            return .place(
                latitude: placeCoordinate.latitude,
                longitude: placeCoordinate.longitude,
                radius: placeRadius,
                placeName: placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "选定的地点"
                    : placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case .date:
            return .date(dateLockTarget)
        case .mood:
            return .mood(notBefore: nil)
        }
    }

    private func bury() {
        let capsule = VoxlueData.Capsule(
            title: title,
            audioData: recording.audioData,
            duration: recording.duration,
            waveform: recording.waveform,
            state: .buried,
            lock: makeLock(),
            recipient: recipient,
            circleID: recipient == .circle ? selectedCircleID : nil
        )
        do {
            let store = CapsuleStore(context: context)
            try store.add(capsule)
            // 给声音圈时同写 circle 关系（D7）—— CKShare 把胶囊挂到 Circle 共享树下的前提。
            if recipient == .circle, let cid = selectedCircleID {
                try? store.assignCircle(capsule, circleID: cid)
            }
            // UI 测试环境下跳过 0.7s 仪式 —— 测试只给 0.8s buffer，且无须再演一次盖章。
            if Self.skipsCeremony {
                onBuried()
                return
            }
            isBurying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                onBuried()
            }
        } catch {
            saveFailed = true
        }
    }

    /// UI 测试（`-uiTestFakeAudio`）或 XCTest 进程下跳过盖章仪式，
    /// 让 `testRecordBuryPlayMainLoop` 的 0.8s buffer 留有富余。
    private static let skipsCeremony: Bool = {
        let info = ProcessInfo.processInfo
        return info.arguments.contains("-uiTestFakeAudio")
            || info.environment["XCTestSessionIdentifier"] != nil
    }()
}

#Preview {
    NavigationStack {
        FramingView(
            recording: RecordingResult(
                audioData: Data("preview".utf8),
                duration: 8,
                waveform: FakeAudioRecording.fakeWaveform
            ),
            onBuried: {}
        )
    }
    .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
    .environment(ServiceContainer.preview())
}
