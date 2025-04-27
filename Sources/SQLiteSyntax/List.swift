//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/26/25.
//

import Foundation

public struct List<Element: Syntax>: Syntax, ExpressibleByArrayLiteral {
    
    
    public var items: Array<Element>
    public var delimiter = ","
    public var includeLeadingDelimeter = false
    
    public init() {
        self.items = []
    }
    
    public init(items: Array<Element>, delimeter: String, includeLeadingDelimeter: Bool) {
        self.items = items
        self.delimiter = delimeter
        self.includeLeadingDelimeter = includeLeadingDelimeter
    }
    
    public init<S>(_ elements: S) where S : Sequence, Element == S.Element {
        self.items = Array(elements)
    }
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
    
    public func validate() throws(SyntaxError) {
        try require(items.count > 0, reason: "A list must contain at least one item")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        if includeLeadingDelimeter { builder.add(delimiter) }
        try builder.addList(items, delimiter: delimiter)
    }
}

/*
 List conforms to various collection protocols to make interacting with it a bit easier
 
 Instead of having to do:
 statement.columns.items.append(...)
 
 You can do:
 statement.columns.append(...)
 */
extension List: RangeReplaceableCollection, BidirectionalCollection, MutableCollection, RandomAccessCollection {
    
    public typealias SubSequence = List<Element>
    public typealias Index = Array<Element>.Index
    
    public var startIndex: Array<Element>.Index { items.startIndex }
    public var endIndex: Array<Element>.Index { items.endIndex }
    public var count: Int { items.count }
    
    public func index(before i: Index) -> Index { items.index(before: i) }
    public func index(after i: Index) -> Index { items.index(after: i) }
    
    public subscript(position: Index) -> Element {
        get { items[position] }
        set { items[position] = newValue }
    }
    public subscript(bounds: Range<Index>) -> List<Element> {
        get { List(items: Array(items[bounds]),
                   delimeter: delimiter,
                   includeLeadingDelimeter: includeLeadingDelimeter) }
        set { items[bounds] = newValue.items[...] }
    }
    
    public mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C : Collection, Element == C.Element {
        items.replaceSubrange(subrange, with: newElements)
    }
}
