//
//  ForeignKeyClause.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

public struct ForeignKeyClause: Syntax {
    
    public enum Action: Syntax {
        case setNull
        case setDefault
        case cascade
        case restrict
        case noAction
    }
    
    public struct Deferral: Syntax {
        
        public enum InitialTiming: Syntax {
            case deferred
            case immediate
        }
        
        public var negated: Bool
        
        public var initialTiming: InitialTiming?
        
        public init(negated: Bool, initialTiming: InitialTiming? = nil) {
            self.negated = negated
            self.initialTiming = initialTiming
        }
    }
    
    public var references: TableName
    
    public var referencedColumns: Array<ColumnName>
    
    public var onDeleteActions: Array<Action>
    
    public var deferral: Deferral?
    
    public init(references: TableName, referencedColumns: Array<ColumnName>, onDeleteActions: Array<Action>, deferral: Deferral? = nil) {
        self.references = references
        self.referencedColumns = referencedColumns
        self.onDeleteActions = onDeleteActions
        self.deferral = deferral
    }
    
}
