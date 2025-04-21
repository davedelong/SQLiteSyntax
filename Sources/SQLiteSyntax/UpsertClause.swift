//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct UpsertClause: Syntax {
    
    public enum Target: Syntax {
        case any
        case columns(Array<IndexedColumn>, where: Expression?)
        
        public func validate() throws(SyntaxError) {
            switch self {
                case .columns(let columns, _):
                    try require(columns.count > 0, reason: "Conflict that target columns require at least one column name")
                default:
                    break
            }
        }
    }
    
    public enum Action: Syntax {
        case nothing
        case update(UpdateStatement.Values, where: Expression?)
    }
    
    public var conflicts: Array<(Target, Action)>
    
    public init(conflicts: Array<(Target, Action)>) {
        self.conflicts = conflicts
    }
    
    public func validate() throws(SyntaxError) {
        try require(conflicts.count > 0, reason: "Upsert clauses require at least one conflict target")
    }
    
}
