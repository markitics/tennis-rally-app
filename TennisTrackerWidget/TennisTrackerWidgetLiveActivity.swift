//
//  TennisTrackerWidgetLiveActivity.swift
//  TennisTrackerWidget
//
//  Created by M@rkMoriarty.com on 9/28/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TennisTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TennisTrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TennisTrackerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TennisTrackerWidgetAttributes {
    fileprivate static var preview: TennisTrackerWidgetAttributes {
        TennisTrackerWidgetAttributes(name: "World")
    }
}

extension TennisTrackerWidgetAttributes.ContentState {
    fileprivate static var smiley: TennisTrackerWidgetAttributes.ContentState {
        TennisTrackerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TennisTrackerWidgetAttributes.ContentState {
         TennisTrackerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TennisTrackerWidgetAttributes.preview) {
   TennisTrackerWidgetLiveActivity()
} contentStates: {
    TennisTrackerWidgetAttributes.ContentState.smiley
    TennisTrackerWidgetAttributes.ContentState.starEyes
}
