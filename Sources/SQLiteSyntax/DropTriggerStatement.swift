//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DropTriggerStatement: Syntax {
    
    public var ifExists: Bool
    public var schemaName: SchemaName?
    public var triggerName: TriggerName
    
    public init(ifExists: Bool, schemaName: SchemaName? = nil, triggerName: TriggerName) {
        self.ifExists = ifExists
        self.schemaName = schemaName
        self.triggerName = triggerName
    }
    
}
