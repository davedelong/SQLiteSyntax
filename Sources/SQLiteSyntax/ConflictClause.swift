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
}
