//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum BindParameter: Syntax {
    
    case next
    case nth(Int)
    case named(String)
    case atNamed(String)
    case tcl(String)
    
}
