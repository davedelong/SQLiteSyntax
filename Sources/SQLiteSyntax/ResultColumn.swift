//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum ResultColumn: Syntax {
    case expression(Expression, alias: Name<Column>?)
    case wildcard(Name<Table>?)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .expression(let e, alias: let alias):
                try builder.add(e)
                try builder.addAlias(alias)
            case .wildcard(let table):
                try builder.add(name: table, .init())
        }
    }
}
