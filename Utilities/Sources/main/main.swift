//
//  File.swift
//  
//
//  Created by YuAo on 2020/3/16.
//

import Foundation
import ArgumentParser
import BoilerplateGenerator

struct Main: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Code Generator Utilities for MetalPetal.",
        subcommands: [BoilerplateGenerator.self],
        defaultSubcommand: nil)
}

Main.main()
