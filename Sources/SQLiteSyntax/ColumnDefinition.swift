//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct ColumnDefinition: Syntax {
    
    public var name: ColumnName
    public var typeName: TypeName?
    public var constraints: Array<ColumnConstraint>
    
    public init(name: ColumnName, typeName: TypeName? = nil, constraints: Array<ColumnConstraint>) {
        self.name = name
        self.typeName = typeName
        self.constraints = constraints
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(name)
        try builder.add(typeName)
        for constraint in constraints {
            try builder.add(constraint)
        }
    }
}
