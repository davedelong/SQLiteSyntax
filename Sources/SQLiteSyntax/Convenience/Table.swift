//
//  Table.swift
//  SQLiteSyntax
//

import Foundation

extension Table {
    public typealias Create = CreateTableStatement
    public typealias Alter = AlterTableStatement
    public typealias Drop = DropTableStatement
}

extension Table.Create {
    
    public init(name: Name<Table>, ifNotExists: Bool = true) {
        self.init(ifNotExists: ifNotExists, tableName: name, definition: .columns(columnDefinitions: []))
    }
    
    public init(name: Name<Table>, ifNotExists: Bool = true, columns: List<ColumnDefinition>) {
        self.init(ifNotExists: ifNotExists, tableName: name, definition: .columns(columnDefinitions: columns))
    }
    
    public var columns: List<ColumnDefinition> {
        get { parts.columns }
        set { var p = parts; p.columns = newValue; parts = p }
    }
    
    public var constraints: [TableConstraint] {
        get { parts.constraints }
        set { var p = parts; p.constraints = newValue; parts = p }
    }
    
    public var options: [TableOptions.OptionsElement] {
        get { parts.options }
        set { var p = parts; p.options = newValue; parts = p }
    }
    
    public mutating func addPrimaryKey(_ name: Name<Column>, type: TypeName, autoincrement: Bool = false) {
        self.columns.append(.primaryKey(name, type: type, autoincrement: autoincrement))
    }
    
    public mutating func addColumn(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true) {
        self.columns.append(.init(name, type: type, canBeNull: canBeNull))
    }
    
    public mutating func addForeignKey(_ name: Name<Column>, references: Name<Table>, column: Name<Column>, type: TypeName? = nil, canBeNull: Bool, onUpdate: ForeignKey.Action? = nil, onDelete: ForeignKey.Action? = nil) {
        self.columns.append(.foreignKey(name, references: references, column: column, type: type, canBeNull: canBeNull, onUpdate: onUpdate, onDelete: onDelete))
    }
    
    // MARK: Helpers
    
    /// The column-list form of the definition (as opposed to `AS select-stmt`).
    private var parts: (columns: List<ColumnDefinition>, constraints: [TableConstraint], options: [TableOptions.OptionsElement]) {
        get {
            guard case .columns(let columns, let constraints, let options) = definition else { return ([], [], []) }
            return (columns, constraints.map { Array($0) } ?? [], options.map { Array($0.options) } ?? [])
        }
        set {
            definition = .columns(columnDefinitions: newValue.columns,
                                  tableConstraints: newValue.constraints.isEmpty ? nil : List(newValue.constraints),
                                  tableOptions: newValue.options.isEmpty ? nil : TableOptions(options: List(newValue.options)))
        }
    }
}
