//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public indirect enum TableOrSubquery: Syntax {
    
    case tableName(SchemaName?, TableName, alias: TableName?, indexedBy: IndexName?)
    case tableFunction(SchemaName?, Name, Array<Expression>, alias: TableName)
    case select(SelectStatement, alias: TableName?)
    case recursive(Array<TableOrSubquery>)
    case join(JoinClause)
    
    public func validate() throws(SyntaxError) {
        switch self {
            case .tableFunction(_, _, let arguments, _):
                try require(arguments.count > 0, reason: "Table function invocations require at least one argument")
            case .recursive(let tablesOrSubqueries):
                try require(tablesOrSubqueries.count > 0, reason: "Recursive tables or subqueries require at least one value")
            default:
                break
        }
    }
}
