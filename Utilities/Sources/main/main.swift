//
//  main.swift
//
//
//  Created by YuAo on 2020/3/16.
//

import Foundation

guard CommandLine.arguments.count == 2 else {
    print("Usage: \(CommandLine.arguments[0]) <the root directory of the MetalPetal repo>")
    exit(1)
}

try generateBoilerplateFiles(projectRoot: URL(fileURLWithPath: CommandLine.arguments[1]))
