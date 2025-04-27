//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum OverClause: Syntax {
    
    case windowName(Name<Window>)
    case expression(Name<Window>?, partitionBy: List<Expression>?, orderBy: OrderBy?, frameSpec: FrameSpec?)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("OVER")
        switch self {
            case .windowName(let w):
                try builder.add(w)
            case .expression(let w, partitionBy: let partition, orderBy: let order, frameSpec: let frame):
                builder.add("(")
                try builder.add(w)
                if let partition {
                    builder.add("PARTITION", "BY")
                    try builder.add(partition)
                }
                try builder.add(order)
                try builder.add(frame)
                builder.add(")")
        }
    }
    
}
