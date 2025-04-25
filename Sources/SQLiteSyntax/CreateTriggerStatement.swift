//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CreateTriggerStatement: Syntax {
    
    public enum Timing: Syntax {
        case before
        case after
        case insteadOf
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .before: builder.add("BEFORE")
                case .after: builder.add("AFTER")
                case .insteadOf: builder.add("INSTEAD", "OF")
            }
        }
    }
    
    public enum Trigger: Syntax {
        case delete
        case insert
        case update(ColumnNameList?)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .delete: builder.add("DELETE")
                case .insert: builder.add("INSERT")
                case .update(let list):
                    builder.add("UPDATE")
                    if let list {
                        builder.add("OF")
                        try builder.add(list)
                    }
            }
        }
    }
    
    public enum Condition: Syntax {
        case forEachRow
        case when(Expression)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .forEachRow:
                    builder.add("FOR", "EACH", "ROW")
                case .when(let e):
                    builder.add("WHEN")
                    try builder.add(e)
            }
        }
    }
    
    public enum Action: Syntax {
        case update(UpdateStatement)
        case insert(InsertStatement)
        case delete(DeleteStatement)
        case select(SelectStatement)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .update(let u): try builder.add(u)
                case .insert(let i): try builder.add(i)
                case .delete(let d): try builder.add(d)
                case .select(let s): try builder.add(s)
            }
        }
    }
    
    public var temporary: Bool
    public var ifNotExists: Bool
    
    public var schemaName: SchemaName?
    public var triggerName: TriggerName
    
    public var timing: Timing?
    public var trigger: Trigger
    
    public var on: TableName
    public var condition: Condition?
    
    public var actions: Array<Action>
    
    public init(temporary: Bool, ifNotExists: Bool, schemaName: SchemaName? = nil, triggerName: TriggerName, timing: Timing? = nil, trigger: Trigger, on: TableName, condition: Condition? = nil, actions: Array<Action>) {
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.triggerName = triggerName
        self.timing = timing
        self.trigger = trigger
        self.on = on
        self.condition = condition
        self.actions = actions
    }
    
    public func validate() throws(SyntaxError) {
        try require(actions.count > 0, reason: "\(Self.self) must have at least one action")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("CREATE")
        if temporary { builder.add("TEMPORARY") }
        builder.add("TRIGGER")
        if ifNotExists { builder.add("IF", "NOT", "EXISTS") }
        try builder.add(name: schemaName, triggerName)
        try builder.add(timing)
        try builder.add(trigger)
        builder.add("ON")
        try builder.add(on)
        try builder.add(condition)
        builder.add("BEGIN")
        
        for action in actions {
            try builder.add(action)
            builder.add(";")
        }
        builder.add("END")
    }
}
