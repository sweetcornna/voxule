//
//  OnboardingView.swift
//  voxule
//
//  首次启动 3 页引导 —— 解释 voxlue「声音的暗房」隐喻。
//  仅出现一次：@AppStorage("voxlue.hasSeenOnboarding") 翻一次就再也不弹。
//

import SwiftUI
import VoxlueDesign

/// 首次启动引导 —— 三页式分镜：
/// 1. 冲一张声音 —— 隐喻入场。
/// 2. 装裱埋下 —— 三把锁（地点 / 时间 / 情绪）。
/// 3. 等它显影 —— 不是提醒事项，是陪伴。
///
/// 显示时机由 `voxuleApp` 中的 `@AppStorage("voxlue.hasSeenOnboarding")` 决定，
/// 点「开始」或「跳过」即写真，下次冷启动就不再弹。
struct OnboardingView: View {
    @AppStorage("voxlue.hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.dismiss) private var dismiss
    @State private var page: Int = 0

    var body: some View {
        ZStack {
            PaperBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    PageOne().tag(0)
                    PageTwo().tag(1)
                    PageThree().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                // 翻页指示点用朱红，统一暗房调。
                .accentColor(VoxlueColor.vermillion)

                bottomBar
            }
        }
        .tint(VoxlueColor.vermillion)
        // 同步系统翻页指示器颜色到朱红。
        .onAppear {
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(VoxlueColor.vermillion)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor(VoxlueColor.darkroomGray)
        }
    }

    /// 底部行动条 —— 朱红「开始」全宽 borderedProminent；前两页底部「跳过」灰小字。
    /// `page > 0` 时主按钮上方再挂一行「上一页」（左对齐石墨小字），方便回看。
    private var bottomBar: some View {
        VStack(spacing: VoxlueSpacing.md) {
            if page > 0 {
                Button {
                    withAnimation { page -= 1 }
                } label: {
                    HStack(spacing: VoxlueSpacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("上一页")
                    }
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.graphite)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VoxlueSpacing.lg)
            }

            Button {
                // 前两页：滑下一页；末页：写下「看过了」并收工。
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page == 2 ? "开始" : "继续")
                    .font(VoxlueTypography.serifTitle)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(VoxlueColor.vermillion)
            .controlSize(.large)

            if page < 2 {
                Button("跳过") {
                    finish()
                }
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.darkroomGray)
            } else {
                // 占位让总高稳定，不抖。
                Text(" ")
                    .font(VoxlueTypography.caption)
            }
        }
        .padding(.horizontal, VoxlueSpacing.xl)
        .padding(.bottom, VoxlueSpacing.lg)
    }

    private func finish() {
        hasSeenOnboarding = true
        dismiss()
    }
}

// MARK: - 三页分镜

/// 第一页 —— 冲一张声音。
private struct PageOne: View {
    var body: some View {
        VStack(spacing: VoxlueSpacing.xl) {
            Spacer()

            Text("voxlue")
                .font(VoxlueTypography.displayHero)
                .foregroundStyle(VoxlueColor.vermillion)

            Text("声音的暗房")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)

            Text("录一段你想留下的声音 —— 一句话、一段笑、风的声音都行。")
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.graphite)
                .multilineTextAlignment(.center)
                .lineSpacing(VoxlueTypography.Step.body.lineSpacing)
                .padding(.horizontal, VoxlueSpacing.xl)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, VoxlueSpacing.lg)
    }
}

/// 第二页 —— 装裱，然后埋下。
private struct PageTwo: View {
    var body: some View {
        VStack(spacing: VoxlueSpacing.xl) {
            Spacer()

            Text("装裱，然后埋下。")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
                .multilineTextAlignment(.center)

            PaperCard {
                VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
                    HStack {
                        SealStamp(.buried)
                        Spacer()
                    }

                    Text("给声音上三把锁：")
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.ink)

                    VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                        lockLine("地点", note: "走到才会浮现")
                        lockLine("时间", note: "到了那天才会浮现")
                        lockLine("情绪", note: "状态对了才会浮现")
                    }
                }
            }
            .padding(.horizontal, VoxlueSpacing.lg)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, VoxlueSpacing.lg)
    }

    private func lockLine(_ key: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: VoxlueSpacing.sm) {
            Text(key)
                .font(VoxlueTypography.serifTitle)
                .foregroundStyle(VoxlueColor.ink)
            Text(note)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
    }
}

/// 第三页 —— 等它自己浮现。
private struct PageThree: View {
    var body: some View {
        VStack(spacing: VoxlueSpacing.xl) {
            Spacer()

            Text("等它自己浮现。")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
                .multilineTextAlignment(.center)

            Text("走到某个地方、到某一天、或安静的时刻 —— 它会自己显影，回到你面前。")
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.graphite)
                .multilineTextAlignment(.center)
                .lineSpacing(VoxlueTypography.Step.body.lineSpacing)
                .padding(.horizontal, VoxlueSpacing.xl)

            // 独立居中场景不再用 MarginNote：原写法「— xxx」文本前缀 + MarginNote
            // 自带朱红短画 = 双重 dash，且 HStack{Spacer; MarginNote} 把整块推到右侧、
            // 与上方居中正文的中轴不齐。改纯居中 Caveat。
            Text("这是陪伴，不是提醒事项。")
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, VoxlueSpacing.xl)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, VoxlueSpacing.lg)
    }
}

#Preview {
    OnboardingView()
}
