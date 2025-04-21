//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct PragmaStatement: Syntax {
    
    public var schemaName: String?
    public var pragmaName: Name
    
    public var value: PragmaValue?
    
    public init(schemaName: String? = nil, pragmaName: Name, value: PragmaValue? = nil) {
        self.schemaName = schemaName
        self.pragmaName = pragmaName
        self.value = value
    }
    
}

public enum PragmaValue: Syntax {
    case number(Decimal)
    case name(Name)
    case literal(String)
}
