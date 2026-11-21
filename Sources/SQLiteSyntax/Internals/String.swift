//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 11/21/26.
//

import Foundation

extension String {

    var containsNull: Bool { utf8.contains(0) }

    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }

}
