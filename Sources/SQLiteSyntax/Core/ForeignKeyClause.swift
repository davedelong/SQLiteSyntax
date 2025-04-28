//
//  ForeignKeyClause.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

public struct ForeignKeyClause: Syntax {
    
    public enum Condition: Syntax {
        case onDelete(Action)
        case onUpdate(Action)
        case match(Name<Any>)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .onDelete(let a):
                    builder.add("ON", "DELETE")
                    try builder.add(a)
                case .onUpdate(let a):
                    builder.add("ON", "UPDATE")
                    try builder.add(a)
                case .match(let n):
                    builder.add("MATCH")
                    try builder.add(n)
            }
        }
    }
    
    public enum Action: Syntax {
        case setNull
        case setDefault
        case cascade
        case restrict
        case noAction
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .setNull: builder.add("SET", "NULL")
                case .setDefault: builder.add("SET", "DEFAULT")
                case .cascade: builder.add("CASCADE")
                case .restrict: builder.add("RESTRICT")
                case .noAction: builder.add("NO", "ACTION")
            }
        }
    }
    
    public struct Deferral: Syntax {
        
        public enum InitialTiming: Syntax {
            case deferred
            case immediate
            
            public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
                switch self {
                    case .deferred: builder.add("INITIALLY", "DEFERRED")
                    case .immediate: builder.add("INITIALLY", "IMMEDIATE")
                }
            }
        }
        
        public var negated: Bool
        
        public var initialTiming: InitialTiming?
        
        public init(negated: Bool, initialTiming: InitialTiming? = nil) {
            self.negated = negated
            self.initialTiming = initialTiming
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            if negated { builder.add("NOT") }
            builder.add("DEFERRABLE")
            try builder.add(initialTiming)
        }
    }
    
    public var references: Name<Table>
    
    public var referencedColumns: List<Name<Column>>?
    
    public var conditions: List<Condition>?
    
    public var deferral: Deferral?
    
    public init(references: Name<Table>, referencedColumns: List<Name<Column>>?, conditions: List<Condition>?, deferral: Deferral? = nil) {
        self.references = references
        self.referencedColumns = referencedColumns
        self.conditions = conditions
        self.deferral = deferral
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("REFERENCES")
        try builder.add(references)
        try builder.add(group: referencedColumns)
        try builder.add(conditions)
        try builder.add(deferral)
    }
    
}
