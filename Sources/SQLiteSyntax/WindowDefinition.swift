//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct WindowDefinition: Syntax {
    
    public var baseWindowName: WindowName?
    
    public var partitionBy: Expression?
    
    public var orderBy: OrderBy?
    
    public var frameSpec: FrameSpec?
    
    public init(baseWindowName: WindowName? = nil, partitionBy: Expression? = nil, orderBy: OrderBy? = nil, frameSpec: FrameSpec? = nil) {
        self.baseWindowName = baseWindowName
        self.partitionBy = partitionBy
        self.orderBy = orderBy
        self.frameSpec = frameSpec
    }
    
}
