//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum TableOption: Syntax {
    case withoutRowID
    case strict
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .withoutRowID: builder.add("WITHOUT", "ROWID")
            case .strict: builder.add("STRICT")
        }
    }
}

