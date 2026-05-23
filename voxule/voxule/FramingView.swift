import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 装裱视图 —— 给录音选锁、选收件人、定标题，确认后埋下。
struct FramingView: View {
    let recording: RecordingResult
    /// 埋下成功后回调，用于关掉整个录音流程。
    let onBuried: () -> Void

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
                    title = draftTitle()
                }
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.vermillion)
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
                Text(lockHint)
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.graphite)

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

    private var lockHint: String {
        switch lockKind {
        case .place: "走到某个地方，它才会显影。地点在地图里细选 —— 计划 03 接入。"
        case .date: "到选定那天，它自己浮现。"
        case .mood: "在你需要的时候，它会被轻轻送来。"
        }
    }

    /// 端侧大模型代写标题的接入点。v1 先用占位实现，计划 06 接 IntelligenceService。
    private func draftTitle() -> String {
        let pool = ["未命名的雨", "某个安静的下午", "留给以后的声音", "一段没说完的话"]
        return pool.randomElement() ?? "未命名"
    }

    /// 由 lockKind 与表单状态组装出最终的 Lock。
    private func makeLock() -> Lock {
        switch lockKind {
        case .place:
            // 地点锁的坐标在计划 03 的地图里细选，这里先落一个占位围栏。
            return .place(latitude: 0, longitude: 0, radius: 100, placeName: "待选地点")
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
            try CapsuleStore(context: context).add(capsule)
            onBuried()
        } catch {
            saveFailed = true
        }
    }
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
