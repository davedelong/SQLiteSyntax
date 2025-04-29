//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/29/25.
//

import Foundation

extension ColumnConstraint {
    
    public static var notNull: Self {
        return .init(name: nil, constraint: .notNull(.none))
    }
    
    public static var unique: Self {
        return .init(name: nil, constraint: .unique(.none))
    }
    
}
