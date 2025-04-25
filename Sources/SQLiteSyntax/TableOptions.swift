//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct TableOptions: Syntax {
    
    public enum Option: Syntax {
        case withoutRowID
        case strict
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .withoutRowID: builder.add("WITHOUT", "ROWID")
                case .strict: builder.add("STRICT")
            }
        }
    }
    
    public var options: Array<Option>
    
    public init(options: Array<Option>) {
        self.options = options
    }
    
    public func validate() throws(SyntaxError) {
        try require(options.count > 0, reason: "Table options must include at least one option")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.addList(options, delimiter: ",")
    }
    
}

