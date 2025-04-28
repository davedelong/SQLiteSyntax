//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct ReleaseStatement: Syntax {
    
    public var savepoint: Bool
    public var savepointName: Name<Savepoint>
    
    public init(savepoint: Bool, savepointName: Name<Savepoint>) {
        self.savepoint = savepoint
        self.savepointName = savepointName
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("RELEASE")
        if savepoint { builder.add("SAVEPOINT") }
        try builder.add(savepointName)
    }
}
