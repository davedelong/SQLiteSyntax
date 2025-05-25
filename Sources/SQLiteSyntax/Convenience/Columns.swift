//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/29/25.
//

import Foundation

extension ColumnDefinition {
    
    public static func primaryKey(_ name: Name<Column>, type: TypeName, autoincrement: Bool = false) -> Self {
        let def = ColumnDefinition(name: name, typeName: type, constraints: [
            .init(name: nil, constraint: .notNull(.none)),
            .init(name: nil, constraint: .primaryKey(nil, .none, autoincrement: autoincrement))
        ])
        return def
    }
    
    public static func foreignKey(_ name: Name<Column>, references: Name<Table>, column: Name<Column>, type: TypeName? = nil, canBeNull: Bool, onUpdate: ForeignKeyClause.Action? = nil, onDelete: ForeignKeyClause.Action? = nil) -> Self {
        
        var clause = ForeignKeyClause(references: references, referencedColumns: [column], conditions: [])
        if let onUpdate { clause.conditions?.append(.onUpdate(onUpdate)) }
        if let onDelete { clause.conditions?.append(.onDelete(onDelete)) }
        
        var def = ColumnDefinition(name: name, typeName: type, constraints: [
            .init(name: nil, constraint: .foreignKey(clause))
        ])
        if canBeNull == false {
            def.constraints?.append(.init(name: nil, constraint: .notNull(.none)))
        }
        return def
    }
    
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true, defaultValue: Expression? = nil) {
        self.init(name, type: type, canBeNull: canBeNull, defaultValue: defaultValue.map { .expression($0) })
    }
    
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true, defaultValue: LiteralValue? = nil) {
        self.init(name, type: type, canBeNull: canBeNull, defaultValue: defaultValue.map { .expression(.literalValue($0)) })
    }
    
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true, defaultValue: String? = nil) {
        self.init(name, type: type, canBeNull: canBeNull, defaultValue: defaultValue.map { .literalValue($0) })
    }
    
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true, defaultValue: ColumnConstraint.DefaultValue? = nil) {
        self.init(name: name, typeName: type, constraints: nil)
        var constraints = Array<ColumnConstraint>()
        if canBeNull == false {
            constraints.append(.init(name: nil, constraint: .notNull(.none)))
        }
        if let defaultValue {
            constraints.append(.init(name: nil, constraint: .default(defaultValue)))
        }
        if constraints.isEmpty == false {
            self.constraints = List(constraints)
        }
    }
    
}

extension ColumnConstraint {
    
    public static var notNull: Self {
        return .init(name: nil, constraint: .notNull(.none))
    }
    
    public static var unique: Self {
        return .init(name: nil, constraint: .unique(.none))
    }
    
}
