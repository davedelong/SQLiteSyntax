//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct WindowDefinition: Syntax {
    
    public var baseWindowName: WindowName?
    
    public var partitionBy: ExpressionList?
    
    public var orderBy: OrderBy?
    
    public var frameSpec: FrameSpec?
    
    public init(baseWindowName: WindowName? = nil, partitionBy: ExpressionList? = nil, orderBy: OrderBy? = nil, frameSpec: FrameSpec? = nil) {
        self.baseWindowName = baseWindowName
        self.partitionBy = partitionBy
        self.orderBy = orderBy
        self.frameSpec = frameSpec
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("(")
        try builder.add(baseWindowName)
        if let partitionBy {
            builder.add("PARTITION", "BY")
            try builder.add(partitionBy)
        }
        try builder.add(orderBy)
        try builder.add(frameSpec)
        builder.add(")")
    }
}
