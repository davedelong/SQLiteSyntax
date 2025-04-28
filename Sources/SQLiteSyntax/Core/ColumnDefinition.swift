//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct ColumnDefinition: Syntax {
    
    public var name: Name<Column>
    public var typeName: TypeName?
    public var constraints: List<ColumnConstraint>?
    
    public init(name: Name<Column>, typeName: TypeName? = nil, constraints: List<ColumnConstraint>?) {
        self.name = name
        self.typeName = typeName
        self.constraints = constraints
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(name)
        try builder.add(typeName)
        try builder.add(constraints)
    }
}
