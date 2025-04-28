//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct VacuumStatement: Syntax {
    
    public var schemaName: Name<Schema>?
    
    public var filename: String?
    
    public init(schemaName: Name<Schema>? = nil, filename: String? = nil) {
        self.schemaName = schemaName
        self.filename = filename
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("VACUUM")
        try builder.add(schemaName)
        if let filename {
            builder.add("INTO", filename)
        }
    }
    
}
