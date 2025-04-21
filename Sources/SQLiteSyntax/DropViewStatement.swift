//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DropViewStatement: Syntax {
    
    public var ifExists: Bool
    public var schemaName: SchemaName?
    public var viewName: ViewName
    
    public init(ifExists: Bool, schemaName: SchemaName? = nil, viewName: ViewName) {
        self.ifExists = ifExists
        self.schemaName = schemaName
        self.viewName = viewName
    }
    
}
