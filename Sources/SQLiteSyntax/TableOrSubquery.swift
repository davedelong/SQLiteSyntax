//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public indirect enum TableOrSubquery: Syntax {
    
    case tableName(SchemaName?, TableName, alias: TableName?, indexedBy: IndexName?)
    case tableFunction(SchemaName?, Name, ExpressionList, alias: TableName)
    case select(SelectStatement, alias: TableName?)
    case recursive(Array<TableOrSubquery>)
    case join(JoinClause)
    
    public func validate() throws(SyntaxError) {
        switch self {
            case .recursive(let tablesOrSubqueries):
                try require(tablesOrSubqueries.count > 0, reason: "Recursive tables or subqueries require at least one value")
            default:
                break
        }
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .tableName(let schema, let table, alias: let alias, indexedBy: let index):
                try builder.add(name: schema, table)
                try builder.addAlias(alias)
                try builder.add(index)
            case .tableFunction(let schema, let name, let args, alias: let alias):
                try builder.add(name: schema, name)
                builder.add("(")
                try builder.add(args)
                builder.add(")")
                try builder.addAlias(alias)
            case .select(let stmt, alias: let alias):
                builder.add("(")
                try builder.add(stmt)
                builder.add(")")
                try builder.addAlias(alias)
            case .recursive(let tableOrSubquery):
                builder.add("(")
                try builder.addList(tableOrSubquery, delimiter: ",")
                builder.add(")")
            case .join(let join):
                builder.add("(")
                try builder.add(join)
                builder.add(")")
        }
    }
}
