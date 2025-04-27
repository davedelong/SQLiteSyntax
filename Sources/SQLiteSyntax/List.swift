//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/26/25.
//

import Foundation

public struct List<T: Syntax>: Syntax, ExpressibleByArrayLiteral {
    
    public var items: Array<T>
    public var delimiter = ","
    public var includeLeadingDelimeter = false
    
    public init(items: Array<T>) {
        self.items = items
    }
    
    public init(arrayLiteral elements: T...) {
        self.init(items: elements)
    }
    
    public func validate() throws(SyntaxError) {
        try require(items.count > 0, reason: "A list must contain at least one item")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        if includeLeadingDelimeter { builder.add(delimiter) }
        try builder.addList(items, delimiter: delimiter)
    }
    
    public mutating func append(_ item: T) {
        self.items.append(item)
    }
}
