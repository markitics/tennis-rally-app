//
//  TennisTrackerWidgetBundle.swift
//  TennisTrackerWidget
//
//  Created by M@rkMoriarty.com on 9/28/25.
//

import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct TennisTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            TennisMatchLiveActivity()
        }
    }
}
