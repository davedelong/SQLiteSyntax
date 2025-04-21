//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct RecursiveCompoundTableExpression: Syntax {
    
    public var tableName: CommonTableExpression.TableName
    public var initialSelect: SelectStatement
    public var unionAll: Bool
    public var recursiveSelect: CompoundSelectStatement
    
    public init(tableName: CommonTableExpression.TableName, initialSelect: SelectStatement, unionAll: Bool, recursiveSelect: CompoundSelectStatement) {
        self.tableName = tableName
        self.initialSelect = initialSelect
        self.unionAll = unionAll
        self.recursiveSelect = recursiveSelect
    }
    
}
