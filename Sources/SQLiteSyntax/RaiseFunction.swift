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
    
}
