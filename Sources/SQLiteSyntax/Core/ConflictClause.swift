//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum ConflictClause: Syntax {
    case none
    case rollback
    case abort
    case fail
    case ignore
    case replace
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .none: break
            case .rollback: builder.add("ON", "CONFLICT", "ROLLBACK")
            case .abort: builder.add("ON", "CONFLICT", "ABORT")
            case .fail: builder.add("ON", "CONFLICT", "FAIL")
            case .ignore: builder.add("ON", "CONFLICT", "IGNORE")
            case .replace: builder.add("ON", "CONFLICT", "REPLACE")
        }
    }
}
