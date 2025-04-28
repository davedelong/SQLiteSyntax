//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/28/25.
//

import Foundation

public typealias Select = SelectStatement

extension Select {
    
    public static func star(from table: Name<Table>) -> Self {
        let core = SelectCore.Core(selection: nil,
                                   columns: [.wildcard(nil)],
                                   from: .tableOrSubquery([.tableName(nil, table, alias: nil, indexedBy: nil)]),
                                   where: nil,
                                   groupBy: [],
                                   having: nil,
                                   window: [])
        return Self.init(with: nil, select: .select(core), additionalSelects: [], orderBy: nil, limit: nil)
    }
    
    public var resultColumns: List<ResultColumn> {
        get { getCore(\.columns) ?? [] }
        set { setCore({ $0.columns = newValue }) }
    }
    
    public var `where`: Expression? {
        get { getCore(\.where) }
        set { setCore({ $0.where = newValue }) }
    }
    
    public var groupBy: Array<Expression> {
        get { getCore(\.groupBy) ?? []}
        set { setCore({ $0.groupBy = newValue }) }
    }
    
    // MARK: Helpers
    
    private func getCore<T>(_ extract: (SelectCore.Core) -> T) -> T? {
        if case .select(let core) = select {
            return extract(core)
        } else {
            return nil
        }
    }
    
    private func getCore<T>(_ extract: (SelectCore.Core) -> T?) -> T? {
        if case .select(let core) = select {
            return extract(core)
        } else {
            return nil
        }
    }
    
    private mutating func setCore(_ block: (inout SelectCore.Core) -> Void) {
        if case .select(var core) = select {
            block(&core)
            self.select = .select(core)
        } else {
            var core = SelectCore.Core(columns: [], groupBy: [], window: [])
            block(&core)
            self.select = .select(core)
        }
    }
}
