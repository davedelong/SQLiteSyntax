//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct RecursiveCompoundTableExpression: Syntax {
    
    public var tableName: CommonTableExpression.Name<Table>
    public var initialSelect: SelectStatement
    public var unionAll: Bool
    public var recursiveSelect: CompoundSelectStatement
    
    public init(tableName: CommonTableExpression.Name<Table>, initialSelect: SelectStatement, unionAll: Bool, recursiveSelect: CompoundSelectStatement) {
        self.tableName = tableName
        self.initialSelect = initialSelect
        self.unionAll = unionAll
        self.recursiveSelect = recursiveSelect
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(tableName)
        builder.add("AS", "(")
        try builder.add(initialSelect)
        builder.add("UNION")
        if unionAll { builder.add("ALL") }
        try builder.add(recursiveSelect)
        builder.add(")")
    }
    
}
