import SwiftUI
import SwiftData
import VoxlueData
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
    @State private var saveFailed = false

    var body: some View {
        Form {
            Section("这一张") {
                LabeledContent("时长", value: durationString)
                WaveformView(samples: recording.waveform, tint: .accentColor)
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("标题") {
                TextField("给这张声音起个名", text: $title)
                Button("让冲洗师代写", systemImage: "wand.and.stars") {
                    title = draftTitle()
                }
                .font(.callout)
            }

            Section("上一把锁") {
                Picker("锁", selection: $lockKind) {
                    Text("地点锁").tag(Lock.Kind.place)
                    Text("时间锁").tag(Lock.Kind.date)
                    Text("情绪锁").tag(Lock.Kind.mood)
                }
                .pickerStyle(.segmented)
                if lockKind == .date {
                    DatePicker("到这天显影", selection: $dateLockTarget,
                               in: Date()..., displayedComponents: [.date])
                }
                Text(lockHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("给谁") {
                Picker("收件人", selection: $recipient) {
                    Text("自己").tag(Recipient.me)
                    Text("声音圈").tag(Recipient.circle)
                }
                Text("收件人埋下时定死，之后不可改。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("装裱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("埋下") { bury() }
            }
        }
        .alert("没能定影", isPresented: $saveFailed) {
            Button("好") {}
        } message: {
            Text("写入失败，请再试一次。")
        }
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
            recipient: recipient
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
}
