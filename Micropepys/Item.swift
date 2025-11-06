//
//  Item.swift
//  Micropepys
//
//  Created by Andrey Osipenko on 06.11.25.
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
