//
//  DoroLiveActivityBridge.swift
//  给 ObjC 的 C 桥：启动/结束灵动岛 Live Activity。
//  编译进主 App（和 DoroActivityAttributes.swift 一起）。
//

import Foundation
import ActivityKit

@_cdecl("doro_live_start")
func doro_live_start(_ titlePtr: UnsafePointer<CChar>?, _ textPtr: UnsafePointer<CChar>?) -> Int32 {
    guard #available(iOS 16.1, *) else { return 0 }
    let title = titlePtr.map { String(cString: $0) } ?? "Doro工具箱"
    let text = textPtr.map { String(cString: $0) } ?? "点我写入脚本"
    do {
        let attrs = DoroActivityAttributes(title: title)
        let state = DoroActivityAttributes.ContentState(text: text)
        _ = try Activity<DoroActivityAttributes>.request(
            attributes: attrs,
            contentState: state,
            pushType: nil
        )
        return 1
    } catch {
        NSLog("[DoroLive] start failed: %@", error.localizedDescription)
        return 0
    }
}

@_cdecl("doro_live_end")
func doro_live_end() {
    guard #available(iOS 16.1, *) else { return }
    Task {
        for activity in Activity<DoroActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
