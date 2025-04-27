//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum ReindexStatement: Syntax {
    case normal
    case collation(Name<Collation>)
    case tableName(Name<Schema>?, Name<Table>)
    case indexName(Name<Schema>?, Name<Index>)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("REINDEX")
        switch self {
            case .normal:
                break
            case .collation(let n):
                try builder.add(n)
            case .tableName(let schema, let table):
                try builder.add(name: schema, table)
            case .indexName(let schema, let index):
                try builder.add(name: schema, index)
        }
    }
}
