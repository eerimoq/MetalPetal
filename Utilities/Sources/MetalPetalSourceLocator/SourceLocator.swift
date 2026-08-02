//
//  SourceLocator.swift
//
//
//  Created by YuAo on 2020/3/16.
//

import Foundation

public func MetalPetalSourcesRootURL(in projectRoot: URL) -> URL {
    projectRoot.appendingPathComponent("Sources/MetalPetal/")
}
