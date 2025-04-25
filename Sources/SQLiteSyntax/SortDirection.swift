//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum SortDirection: Syntax {
    case ascending
    case descending
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .ascending: builder.add("ASC")
            case .descending: builder.add("DESC")
        }
    }
}
