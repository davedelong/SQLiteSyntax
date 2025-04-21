//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct VacuumStatement: Syntax {
    
    public var schemaName: SchemaName?
    
    public var filename: String?
    
    public init(schemaName: SchemaName? = nil, filename: String? = nil) {
        self.schemaName = schemaName
        self.filename = filename
    }
    
}
