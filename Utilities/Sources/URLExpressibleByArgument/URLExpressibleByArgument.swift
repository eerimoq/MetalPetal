//
//  URLExpressibleByArgument.swift
//
//
//  Created by YuAo on 2020/3/16.
//

import ArgumentParser
import Foundation

extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        if let url = URL(string: argument), url.scheme != nil {
            self.init(string: argument)
        } else {
            // Assuming it is a file url.
            self.init(fileURLWithPath: argument)
        }
    }
}
