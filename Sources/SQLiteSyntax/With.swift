//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct With: Syntax {
    public var recursive: Bool
    public var commonTableExpressions: List<CommonTableExpression>
    
    public init(recursive: Bool, commonTableExpressions: List<CommonTableExpression>) {
        self.recursive = recursive
        self.commonTableExpressions = commonTableExpressions
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("WITH")
        if recursive { builder.add("RECURSIVE") }
        try builder.add(commonTableExpressions)
    }
}
