//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum AnalyzeStatement: Syntax {
    
    case blank
    case schema(Name<Schema>)
    case index(Name<Schema>?, Name<Index>)
    case table(Name<Schema>?, Name<Table>)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("ANALYZE")
        switch self {
            case .blank: break
            case .schema(let s): try builder.add(s)
            case .index(let s, let i): try builder.add(name: s, i)
            case .table(let s, let t): try builder.add(name: s, t)
        }
    }
}
