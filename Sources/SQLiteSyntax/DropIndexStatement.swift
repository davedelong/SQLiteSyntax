//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DropIndexStatement: Syntax {
    
    public var ifExists: Bool
    
    public var schemaName: String?
    
    public var indexName: IndexName
    
    public init(ifExists: Bool, schemaName: String? = nil, indexName: IndexName) {
        self.ifExists = ifExists
        self.schemaName = schemaName
        self.indexName = indexName
    }
    
}
