//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum ReindexStatement: Syntax {
    case normal
    case collation(CollationName)
    case tableName(SchemaName?, TableName)
    case indexName(SchemaName?, IndexName)
}
