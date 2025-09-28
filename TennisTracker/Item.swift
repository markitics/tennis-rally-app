//
//  Item.swift
//  TennisTracker
//
//  Created by M@rkMoriarty.com on 9/27/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
