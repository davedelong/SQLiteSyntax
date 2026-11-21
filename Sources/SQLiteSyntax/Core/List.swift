/// A list that must contain at least one item, printed with commas between the items.
///
/// Generated types use `List` where the grammar requires at least one item (`x { ',' x }`), and a plain
/// array where the list may be empty. Lists with another delimiter (such as `;` in `SQLStatementList`)
/// are printed by their generated `build(using:)`, which passes the delimiter itself.
///
/// `List` is a collection and can be written as an array literal:
///
/// ```swift
/// statement.columns = []
/// statement.columns.append(...)
/// ```
public struct List<Element: Syntax>: Syntax {

    public var items: [Element]

    public init() {
        self.items = []
    }

    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.items = Array(elements)
    }

    public func validate() throws(SyntaxError) {
        try require(!items.isEmpty, reason: "A list must contain at least one item")
    }

    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.addList(items, delimiter: ",")
    }

    /// One or more items separated by commas.
    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        List(try p.separated(by: [","]) { (p: inout Parser) throws(ParseError) -> Element in try Element.parse(&p) })
    }
}

extension List: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension List: RangeReplaceableCollection, BidirectionalCollection, MutableCollection, RandomAccessCollection {

    public typealias SubSequence = List<Element>
    public typealias Index = [Element].Index

    public var startIndex: Index { items.startIndex }
    public var endIndex: Index { items.endIndex }
    public var count: Int { items.count }

    public func index(before i: Index) -> Index { items.index(before: i) }
    public func index(after i: Index) -> Index { items.index(after: i) }

    public subscript(position: Index) -> Element {
        get { items[position] }
        set { items[position] = newValue }
    }

    public subscript(bounds: Range<Index>) -> List<Element> {
        get { List(items[bounds]) }
        set { items[bounds] = newValue.items[...] }
    }

    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Index>, with newElements: C) where C.Element == Element {
        items.replaceSubrange(subrange, with: newElements)
    }
}
