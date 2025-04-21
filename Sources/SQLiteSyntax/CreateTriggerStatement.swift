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
    }
    
    public enum Trigger: Syntax {
        case delete
        case insert
        case update(Array<ColumnName>)
    }
    
    public enum Condition: Syntax {
        case forEachRow
        case when(Expression)
    }
    
    public enum Action: Syntax {
        case update(UpdateStatement)
        case insert(InsertStatement)
        case delete(DeleteStatement)
        case select(SelectStatement)
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
}
