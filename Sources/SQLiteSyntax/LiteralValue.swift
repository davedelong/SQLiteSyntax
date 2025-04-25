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
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .number(let d): builder.add(d.description)
            case .string(let s): builder.add(s)
            case .blob(let d):
                let hex = d.map { String($0, radix: 16, uppercase: true) }.joined()
                builder.add("X'\(hex)'")
            case .null: builder.add("NULL")
            case .true: builder.add("TRUE")
            case .false: builder.add("FALSE")
            case .currentTime: builder.add("CURRENT_TIME")
            case .currentDate: builder.add("CURRENT_DATE")
            case .currentTimestamp: builder.add("CURRENT_TIMESTAMP")
        }
    }
    
}
