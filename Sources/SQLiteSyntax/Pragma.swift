//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct PragmaStatement: Syntax {
    
    public var schemaName: SchemaName?
    public var pragmaName: Name
    
    public var value: PragmaValue?
    
    public init(schemaName: SchemaName? = nil, pragmaName: Name, value: PragmaValue? = nil) {
        self.schemaName = schemaName
        self.pragmaName = pragmaName
        self.value = value
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("PRAGMA")
        try builder.add(name: schemaName, pragmaName)
        if let value {
            builder.add("=")
            try builder.add(value)
        }
    }
    
}

public enum PragmaValue: Syntax {
    case number(Decimal)
    case name(Name)
    case literal(String)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .number(let d): builder.add(d.description)
            case .name(let n): try builder.add(n)
            case .literal(let s): builder.add(s)
        }
    }
}
