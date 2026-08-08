//
//  BoilerplateGenerator.swift
//
//
//  Created by YuAo on 2020/3/16.
//

import Foundation

func generateBoilerplateFiles(projectRoot: URL) throws {
    let sourceDirectory = projectRoot.appending(path: "Sources/MetalPetal/")
    let generatedDirectory = sourceDirectory.appending(component: "Generated")
    let shadersDirectory = sourceDirectory.appending(component: "Shaders")
    try write(generateMtiVectorSimd(), to: generatedDirectory)
    try write(generateMtiSimdArgumentValue(), to: generatedDirectory)
    try write(
        generateBlendFormulaSupportFiles(sourceDirectory: sourceDirectory),
        to: generatedDirectory
    )
    try write(generateBlenders(), to: shadersDirectory)
}

private func write(_ files: [String: String], to directory: URL) throws {
    for (file, content) in files {
        try content.write(to: directory.appending(component: file), atomically: true, encoding: .utf8)
    }
}
