//
//  Lists.swift
//  SQLiteSyntax
//

/// `["a", "b"]` for `( a , b )`.
extension ColumnNameList: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Name<Column>...) {
        self.init(columnNames: List(elements))
    }
}

/// `[1, "x"]` for one `VALUES` row `( 1 , 'x' )`.
extension ValuesClause.ValuesElement: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Expression...) {
        self.init(expressions: List(elements))
    }
}
