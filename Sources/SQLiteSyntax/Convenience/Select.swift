//
//  Select.swift
//  SQLiteSyntax
//

import Foundation

public typealias Select = SelectStatement

extension Select {
    
    public static func star(from table: Name<Table>) -> Self {
        Self(selectCore: .select(resultColumns: [.star()], source: .from(from: .tables([.tableName(tableName: table)]))))
    }
    
    public var resultColumns: List<ResultColumn> {
        get { core?.resultColumns ?? [] }
        set { updateCore { $0.resultColumns = newValue } }
    }
    
    public var `where`: Expression? {
        get {
            switch core?.source {
                case .from(_, let condition)?: return condition
                case .where(let condition)?: return condition
                case nil: return nil
            }
        }
        set {
            updateCore { core in
                switch core.source {
                    case .from(let from, _)?: core.source = .from(from: from, where: newValue)
                    case .where?, nil: core.source = newValue.map { .where($0) }
                }
            }
        }
    }
    
    public var groupBy: Array<Expression> {
        get { core?.groupBy.map(Array.init) ?? [] }
        set { updateCore { $0.groupBy = newValue.isEmpty ? nil : List(newValue) } }
    }
    
    // MARK: Helpers
    
    /// The parts of a `SELECT …` core (as opposed to a `VALUES` clause).
    private struct Core {
        var selection: SelectCore.Selection?
        var resultColumns: List<ResultColumn>
        var source: SelectCore.Source?
        var groupBy: List<Expression>?
        var having: Expression?
        var window: List<SelectCore.WindowElement>?
    }
    
    private var core: Core? {
        guard case .select(let selection, let columns, let source, let groupBy, let having, let window) = selectCore else { return nil }
        return Core(selection: selection, resultColumns: columns, source: source, groupBy: groupBy, having: having, window: window)
    }
    
    private mutating func updateCore(_ block: (inout Core) -> Void) {
        var core = self.core ?? Core(resultColumns: [])
        block(&core)
        selectCore = .select(selection: core.selection, resultColumns: core.resultColumns, source: core.source,
                             groupBy: core.groupBy, having: core.having, window: core.window)
    }
}
