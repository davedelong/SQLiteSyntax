//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct FrameSpec: Syntax {
    
    public enum Target: Syntax {
        case range
        case rows
        case groups
    }
    
    public enum Scope: Syntax {
        
        public enum LowerBound: Syntax {
            case unboundedPreceding
            case preceding(Expression)
            case currentRow
            case following(Expression)
        }
        
        public enum UpperBound: Syntax {
            case preceding(Expression)
            case currentRow
            case following(Expression)
            case unboundedFollowing
        }
        
        case between(LowerBound, UpperBound)
        case unboundedPreceding
        case preceding(Expression)
        case currentRow
    }
    
    public enum Exclude: Syntax {
        case noOthers
        case currentRow
        case group
        case ties
    }
    
    public var target: Target
    
    public var scope: Scope
    
    public var exclude: Exclude?
    
    public init(target: Target, scope: Scope, exclude: Exclude? = nil) {
        self.target = target
        self.scope = scope
        self.exclude = exclude
    }
}
