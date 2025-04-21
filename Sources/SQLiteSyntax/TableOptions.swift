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
    }
    
    public var options: Array<Option>
    
    public init(options: Array<Option>) {
        self.options = options
    }
    
    public func validate() throws(SyntaxError) {
        try require(options.count > 0, reason: "Table options must include at least one option")
    }
    
}

