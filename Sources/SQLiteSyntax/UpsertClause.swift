//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct UpsertClause: Syntax {
    
    public struct Target: Syntax {
        var columns: List<IndexedColumn>
        var `where`: Expression?
        
        public init(columns: List<IndexedColumn>, `where`: Expression?) {
            self.columns = columns
            self.where = `where`
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            try builder.add(group: columns)
            if let `where` {
                builder.add("WHERE")
                try builder.add(`where`)
            }
        }
    }
    
    public enum Action: Syntax {
        case nothing
        case update(UpdateStatement.Values, where: Expression?)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .nothing:
                    builder.add("NOTHING")
                case .update(let values, where: let expr):
                    builder.add("UPDATE", "SET")
                    try builder.add(values)
                    if let expr {
                        builder.add("WHERE")
                        try builder.add(expr)
                    }
            }
        }
    }
    
    public var conflicts: Array<(Target?, Action)>
    
    public init(conflicts: Array<(Target?, Action)>) {
        self.conflicts = conflicts
    }
    
    public func validate() throws(SyntaxError) {
        try require(conflicts.count > 0, reason: "Upsert clauses require at least one conflict target")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        for (target, action) in conflicts {
            builder.add("ON", "CONFLICT")
            try builder.add(target)
            builder.add("DO")
            try builder.add(action)
        }
    }
}
