//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DropTriggerStatement: Syntax {
    
    public var ifExists: Bool
    public var schemaName: Name<Schema>?
    public var triggerName: Name<Trigger>
    
    public init(ifExists: Bool, schemaName: Name<Schema>? = nil, triggerName: Name<Trigger>) {
        self.ifExists = ifExists
        self.schemaName = schemaName
        self.triggerName = triggerName
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("DROP", "TRIGGER")
        if ifExists { builder.add("IF", "EXISTS") }
        try builder.add(name: schemaName, triggerName)
    }
    
}
