//
//  TennisTrackerWidgetBundle.swift
//  TennisTrackerWidget
//
//  Created by M@rkMoriarty.com on 9/28/25.
//

import WidgetKit
import SwiftUI

@main
struct TennisTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TennisTrackerWidget()
        TennisTrackerWidgetControl()
        TennisTrackerWidgetLiveActivity()
    }
}
