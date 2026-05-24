import SwiftUI
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 建一个新声音圈。圈名非空即可提交。
struct CreateCircleView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    /// 建圈成功回调，把新圈交回上层（如建完即推进详情页）。
    var onCreated: (VoxlueData.Circle) -> Void = { _ in }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 给圈用的 emoji 池 —— 与 CircleListView 同一份，顺序一致才能保证预览和列表里看到同一个 emoji。
    /// 改池子前注意：池长决定 hash 落点，同名圈的 emoji 会随之漂移。
    private static let circleEmojiPool: [String] = [
        "🏠", "👨‍👩‍👧", "👫", "🌿", "🎵", "🌙", "🍵", "🌊", "🕯", "📷"
    ]

    /// 由圈名 hash 出 emoji，空名返回空心圆点。逻辑与 CircleListView.emoji(forName:) 等价。
    private static func emoji(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "○" }
        return circleEmojiPool[abs(trimmed.hashValue) % circleEmojiPool.count]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("给这个圈起个名字", text: $name)
                        .font(VoxlueTypography.serifBody)
                        .textInputAutocapitalization(.never)
                        .onChange(of: name) { _, new in
                            if new.count > 20 { name = String(new.prefix(20)) }
                        }

                    Text("\(trimmedName.count) / 20")
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(trimmedName.count >= 17 ? VoxlueColor.vermillion : VoxlueColor.graphite)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: VoxlueSpacing.sm) {
                        Text(Self.emoji(for: trimmedName))
                            .font(.system(size: 24))
                            .frame(width: 32, height: 32)
                            .background(VoxlueColor.paperShadow.opacity(0.4), in: Circle())
                        Text("圈头像预览")
                            .font(VoxlueTypography.meta)
                            .foregroundStyle(VoxlueColor.graphite)
                        Spacer()
                    }
                    .padding(.top, VoxlueSpacing.xs)
                } header: {
                    Text("声音圈")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.graphite)
                        .textCase(nil)
                } footer: {
                    Text("家人或挚友的小圈子。圈内能听到彼此埋下的胶囊。")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.darkroomGray)
                }

                if let errorText {
                    Section {
                        Label {
                            Text(errorText)
                                .font(VoxlueTypography.caption)
                                .foregroundStyle(VoxlueColor.ink)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(VoxlueColor.vermillion)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VoxlueColor.paper.ignoresSafeArea())
            .navigationTitle("新建声音圈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(VoxlueColor.graphite)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建好这个圈") { submit() }
                        .disabled(trimmedName.isEmpty || trimmedName.count > 20 || isSubmitting)
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.vermillion)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .tint(VoxlueColor.vermillion)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        errorText = nil
        Task {
            do {
                let circle = try await services.circleService.createCircle(name: trimmedName)
                isSubmitting = false
                onCreated(circle)
                dismiss()
            } catch CircleServiceError.emptyCircleName {
                errorText = "圈名不能为空。"
                isSubmitting = false
            } catch CircleServiceError.cloudKitUnavailable {
                errorText = "iCloud 暂时连不上，请稍后再建。"
                isSubmitting = false
            } catch {
                errorText = "建圈失败：\(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

#Preview {
    CreateCircleView()
        .environment(ServiceContainer.preview())
}
