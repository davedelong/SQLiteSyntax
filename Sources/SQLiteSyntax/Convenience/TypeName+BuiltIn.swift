//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/28/25.
//

import Foundation

extension TypeName {
    
    public static let integer = TypeName(names: [.init(value: "INTEGER")])
    public static let text = TypeName(names: [.init(value: "TEXT")])
    public static let blob = TypeName(names: [.init(value: "BLOB")])
    public static let real = TypeName(names: [.init(value: "REAL")])
    public static let numeric = TypeName(names: [.init(value: "NUMERIC")])
    
}
