//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum RaiseFunction: Syntax {
    
    case ignore
    case rollback(Expression)
    case abort(Expression)
    case fail(Expression)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("RAISE", "(")
        switch self {
            case .ignore:
                builder.add("IGNORE")
            case .rollback(let e):
                builder.add("ROLLBACK", ",")
                try builder.add(e)
            case .abort(let e):
                builder.add("ABORT", ",")
                try builder.add(e)
            case .fail(let e):
                builder.add("FAIL", ",")
                try builder.add(e)
        }
        builder.add(")")
    }
    
}
