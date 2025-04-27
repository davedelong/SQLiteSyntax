//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public indirect enum TableOrSubquery: Syntax {
    
    case tableName(Name<Schema>?, Name<Table>, alias: Name<Table>?, indexedBy: Name<Index>?)
    case tableFunction(Name<Schema>?, Name<Function>, List<Expression>, alias: Name<Table>)
    case select(SelectStatement, alias: Name<Table>?)
    case recursive(List<TableOrSubquery>)
    case join(JoinClause)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .tableName(let schema, let table, alias: let alias, indexedBy: let index):
                try builder.add(name: schema, table)
                try builder.addAlias(alias)
                try builder.add(index)
            case .tableFunction(let schema, let name, let args, alias: let alias):
                try builder.add(name: schema, name)
                try builder.add(group: args)
                try builder.addAlias(alias)
            case .select(let stmt, alias: let alias):
                try builder.add(group: stmt)
                try builder.addAlias(alias)
            case .recursive(let tableOrSubquery):
                try builder.add(group: tableOrSubquery)
            case .join(let join):
                try builder.add(group: join)
        }
    }
}
