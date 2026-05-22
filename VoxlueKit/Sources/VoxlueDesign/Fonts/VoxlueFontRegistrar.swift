import CoreText
import Foundation
import os

/// VoxlueDesign 字体注册器。
/// 包资源里的字体须在运行时经 CoreText 注册系统才认。
/// `registerAll()` 幂等 —— 多次调用只真正注册一次。
public enum VoxlueFontRegistrar {

    private static let lock = OSAllocatedUnfairLock(initialState: false)
    private static let log = Logger(subsystem: "VoxlueDesign", category: "fonts")

    /// 字体是否已注册。
    public static var isRegistered: Bool {
        lock.withLock { $0 }
    }

    /// 注册全部随包字体。幂等：重复调用安全、不重复注册。
    public static func registerAll() {
        lock.withLock { done in
            guard !done else { return }
            for file in VoxlueFontFile.allCases {
                register(file)
            }
            done = true
        }
    }

    private static func register(_ file: VoxlueFontFile) {
        guard let url = file.url else {
            log.error("字体资源缺失：\(file.rawValue, privacy: .public)")
            return
        }
        var errorRef: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef)
        if !ok {
            // 「已注册过」不算失败 —— 测试环境会重复加载进程。
            let code = (errorRef?.takeUnretainedValue() as Error?).map {
                ($0 as NSError).code
            }
            if code == CTFontManagerError.alreadyRegistered.rawValue {
                log.debug("字体已注册：\(file.rawValue, privacy: .public)")
            } else {
                log.error("字体注册失败：\(file.rawValue, privacy: .public)")
            }
        }
        errorRef?.release()
    }
}
