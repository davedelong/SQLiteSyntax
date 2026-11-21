//
//  Columns.swift
//  SQLiteSyntax
//

import Foundation

extension ForeignKey {
    /// What happens to a referencing row when the referenced row is deleted or updated.
    public typealias Action = ActionsElement.Action
}

extension ColumnDefinition {
    
    public static func primaryKey(_ name: Name<Column>, type: TypeName, autoincrement: Bool = false) -> Self {
        ColumnDefinition(name: name, typeName: type, constraints: [
            .notNull,
            .init(constraint: .primaryKey(autoincrement: autoincrement))
        ])
    }
    
    public static func foreignKey(_ name: Name<Column>, references: Name<Table>, column: Name<Column>, type: TypeName? = nil, canBeNull: Bool, onUpdate: ForeignKey.Action? = nil, onDelete: ForeignKey.Action? = nil) -> Self {
        var clause = ForeignKey(foreignTable: references, columns: ColumnNameList(columnNames: [column]))
        if let onUpdate { clause.actions.append(.on(on: .update, action: onUpdate)) }
        if let onDelete { clause.actions.append(.on(on: .delete, action: onDelete)) }
        var definition = ColumnDefinition(name: name, typeName: type, constraints: [.init(constraint: .foreignKey(clause))])
        if canBeNull == false {
            definition.constraints.append(.notNull)
        }
        return definition
    }
    
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true) {
        self.init(name, type: type, canBeNull: canBeNull, defaultValue: ColumnConstraint.Constraint.Default?.none)
    }
    
    @_disfavoredOverload
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true, defaultValue: Expression? = nil) {
        self.init(name, type: type, canBeNull: canBeNull, defaultValue: defaultValue.map { .expression($0) })
    }
    
    @_disfavoredOverload
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true, defaultValue: LiteralValue? = nil) {
        self.init(name, type: type, canBeNull: canBeNull, defaultValue: defaultValue.map { ColumnConstraint.Constraint.Default.literalValue($0) })
    }
    
    @_disfavoredOverload
    public init(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true, defaultValue: ColumnConstraint.Constraint.Default? = nil) {
        self.init(name: name, typeName: type)
        if canBeNull == false {
            constraints.append(.notNull)
        }
        if let defaultValue {
            constraints.append(.init(constraint: .default(defaultValue)))
        }
    }
}

extension ColumnConstraint {
    
    public static var notNull: Self {
        .init(constraint: .notNull())
    }
    
    public static var unique: Self {
        .init(constraint: .unique())
    }
}
