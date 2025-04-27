//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct SavepointStatement: Syntax {
    
    public var savepointName: Name<Savepoint>
    
    public init(savepointName: Name<Savepoint>) {
        self.savepointName = savepointName
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("SAVEPOINT")
        try builder.add(savepointName)
    }
    
}
