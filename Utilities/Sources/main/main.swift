//
//  main.swift
//
//
//  Created by YuAo on 2020/3/16.
//

import ArgumentParser
import BoilerplateGenerator
import Foundation

struct Main: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Code Generator Utilities for MetalPetal.",
        subcommands: [BoilerplateGenerator.self],
        defaultSubcommand: nil
    )
}

Main.main()
