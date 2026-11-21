//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/28/25.
//

import Foundation

extension TypeName {
    
    public static let integer = TypeName(typeWords: [.init(value: "INTEGER")])
    public static let text = TypeName(typeWords: [.init(value: "TEXT")])
    public static let blob = TypeName(typeWords: [.init(value: "BLOB")])
    public static let real = TypeName(typeWords: [.init(value: "REAL")])
    public static let numeric = TypeName(typeWords: [.init(value: "NUMERIC")])
    
}
