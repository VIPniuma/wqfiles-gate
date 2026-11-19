//
//  DoroActivityAttributes.swift
//  Live Activity 共享模型：主 App 与 Widget Extension 都编译这个文件。
//  点击灵动岛/锁屏视图时用 doro://write 拉回工具箱触发写入。
//

import Foundation
import ActivityKit

struct DoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var text: String
    }
    var title: String
}
