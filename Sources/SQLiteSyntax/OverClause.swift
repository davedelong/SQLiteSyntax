//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum OverClause: Syntax {
    
    case windowName(WindowName)
    case expression(WindowName?, partitionBy: Array<Expression>?, orderBy: OrderBy?, frameSpec: FrameSpec?)
    
}
