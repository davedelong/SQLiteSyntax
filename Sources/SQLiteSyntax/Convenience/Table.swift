//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/28/25.
//

import Foundation

extension Table {
    public typealias Create = CreateTableStatement
    public typealias Alter = AlterTableStatement
    public typealias Drop = DropTableStatement
}

extension Table.Create {
    
    public init(name: Name<Table>, ifNotExists: Bool = true) {
        self.init(temporary: false, ifNotExists: ifNotExists, tableName: name, contents: .columns([], nil, nil))
    }
    
    public var columns: List<ColumnDefinition> {
        get {
            guard case .columns(let c, _, _) = contents else { return [] }
            return c
        }
        set {
            if case .columns(_, let con, let opt) = contents {
                self.contents = .columns(newValue, con, opt)
            } else {
                self.contents = .columns(newValue, nil, nil)
            }
        }
    }
    
    public var constraints: List<TableConstraint> {
        get {
            guard case .columns(_, let c, _) = contents else { return [] }
            return c ?? []
        }
        set {
            if case .columns(let col, _, let opt) = contents {
                self.contents = .columns(col, newValue, opt)
            } else {
                self.contents = .columns([], newValue, nil)
            }
        }
    }
    
    public var options: List<TableOption> {
        get {
            guard case .columns(_, _, let c) = contents else { return [] }
            return c ?? []
        }
        set {
            if case .columns(let col, let con, _) = contents {
                self.contents = .columns(col, con, newValue)
            } else {
                self.contents = .columns([], nil, newValue)
            }
        }
    }
    
    public mutating func addPrimaryKey(_ name: Name<Column>, type: TypeName, autoincrement: Bool = false) {
        let def = ColumnDefinition(name: name, typeName: type, constraints: [
            .init(name: nil, constraint: .notNull(.none)),
            .init(name: nil, constraint: .primaryKey(nil, .none, autoincrement: autoincrement))
        ])
        
        self.columns.append(def)
    }
    
    public mutating func addColumn(_ name: Name<Column>, type: TypeName, canBeNull: Bool = true) {
        var def = ColumnDefinition(name: name, typeName: type, constraints: nil)
        if canBeNull == false {
            def.constraints = [.init(name: nil, constraint: .notNull(.none))]
        }
        
        self.columns.append(def)
    }
    
    public mutating func addForeignKey(_ name: Name<Column>, references: Name<Table>, column: Name<Column>, canBeNull: Bool, onUpdate: ForeignKeyClause.Action? = nil, onDelete: ForeignKeyClause.Action? = nil) {
        
        var clause = ForeignKeyClause(references: references, referencedColumns: [column], conditions: [])
        if let onUpdate { clause.conditions?.append(.onUpdate(onUpdate)) }
        if let onDelete { clause.conditions?.append(.onDelete(onDelete)) }
        
        var def = ColumnDefinition(name: name, constraints: [
            .init(name: nil, constraint: .foreignKey(clause))
        ])
        if canBeNull == false {
            def.constraints?.append(.init(name: nil, constraint: .notNull(.none)))
        }
        self.columns.append(def)
    }
}
