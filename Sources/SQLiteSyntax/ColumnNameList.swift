//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct ColumnNameList: Syntax {
    
    public var names: Array<ColumnName>
    
    public init(names: Array<ColumnName>) {
        self.names = names
    }
    
    public func validate() throws(SyntaxError) {
        try require(names.count > 0, reason: "A list of column names must contain at least one name")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.addList(names, delimiter: ",")
    }
}
