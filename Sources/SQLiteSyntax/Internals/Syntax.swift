//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public protocol Syntax: Sendable {
    
    func validate() throws(SyntaxError)
    
}

public enum SyntaxError: Error {
    case invalidSyntax(any Syntax, reason: String)
}

extension Syntax {
    
    public func validate() throws(SyntaxError) { }
    
    internal func require(_ expression: Bool, reason: String) throws(SyntaxError) {
        if expression == false {
            throw SyntaxError.invalidSyntax(self, reason: reason)
        }
    }
    
}
