//
//  DoroWidget.swift
//  Widget Extension：灵动岛 + 锁屏 Live Activity 视图。
//  与 DoroActivityAttributes.swift 一起编译进 appex。
//  点击「写入脚本」按钮用 doro://write 拉回工具箱（在 main.m openURL 里触发写入）。
//

import SwiftUI
import WidgetKit
import ActivityKit

@main
struct DoroWidgetBundle: WidgetBundle {
    var body: some Widget {
        DoroLiveWidget()
    }
}

struct DoroLiveWidget: Widget {
    let kind: String = "DoroLiveWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoroActivityAttributes.self) { context in
            // 锁屏 / 通知中心横幅
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(context.attributes.title).font(.headline)
                    Spacer()
                    Link(destination: URL(string: "doro://write")!) {
                        Text("写入脚本").font(.subheadline.weight(.bold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.pink.opacity(0.85))
                            .foregroundColor(.white).cornerRadius(12)
                    }
                }
                Text(context.state.text).font(.caption).foregroundColor(.secondary)
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态
                DynamicIslandExpandedRegion(.leading) {
                    Text("Doro").font(.caption.weight(.bold)).foregroundColor(.pink)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "doro://write")!) {
                        Text("写入").font(.caption.weight(.bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.pink.opacity(0.85))
                            .foregroundColor(.white).cornerRadius(10)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.text).font(.caption)
                }
            } compactLeading: {
                Text("Doro").font(.caption2.weight(.bold)).foregroundColor(.pink)
            } compactTrailing: {
                Link(destination: URL(string: "doro://write")!) {
                    Image(systemName: "bolt.fill").foregroundColor(.pink)
                }
            } minimal: {
                Link(destination: URL(string: "doro://write")!) {
                    Image(systemName: "bolt.fill").foregroundColor(.pink)
                }
            }
            .widgetURL(URL(string: "doro://write"))
            .keylineTint(Color.pink)
        }
    }
}
