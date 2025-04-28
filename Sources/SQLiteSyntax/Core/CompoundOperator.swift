//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum CompoundOperator: Syntax {
    
    case union
    case unionAll
    case intersect
    case except
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .union: builder.add("UNION")
            case .unionAll: builder.add("UNION", "ALL")
            case .intersect: builder.add("INTERSECT")
            case .except: builder.add("EXCEPT")
        }
    }
    
}
