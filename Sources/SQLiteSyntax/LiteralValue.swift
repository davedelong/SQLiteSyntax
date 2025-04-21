//
//  LiteralValue.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum LiteralValue: Syntax {
    
    case number(Decimal)
    case string(String)
    case blob(Data)
    case null
    case `true`
    case `false`
    case currentTime
    case currentDate
    case currentTimestamp
    
}
