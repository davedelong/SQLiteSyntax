//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct Name<T>: Syntax {
    
    public var value: String
    
    public init(value: String) where T == Any {
        self.value = value
    }
    
    public init(value: String) where T: NamedStructure {
        self.value = value
    }
    
    public func validate() throws(SyntaxError) {
        // check validity
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(value)
    }
    
}

extension Name: ExpressibleByUnicodeScalarLiteral, ExpressibleByExtendedGraphemeClusterLiteral, ExpressibleByStringLiteral where T: NamedStructure {
    
    public init(stringLiteral value: String) {
        self.init(value: value)
    }
    
}

public protocol NamedStructure { }

public enum Table: NamedStructure { }
public enum Schema: NamedStructure { }
public enum Column: NamedStructure { }
public enum Function: NamedStructure { }
public enum Index: NamedStructure { }
public enum Trigger: NamedStructure { }
public enum View: NamedStructure { }
public enum Module: NamedStructure { }
public enum Collation: NamedStructure { }
public enum Window: NamedStructure { }
public enum Savepoint: NamedStructure { }
