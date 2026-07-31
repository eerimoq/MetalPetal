//
//  MTIMemoryWarningObserver.swift
//  MetalPetal
//
//  Created by Yu Ao on 2018/8/27.
//

import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

public protocol MTIMemoryWarningHandling: AnyObject {
    func handleMemoryWarning()
}

public final class MTIMemoryWarningObserver {
    private static let sharedObserver = MTIMemoryWarningObserver()

    private let handlers = NSHashTable<AnyObject>.weakObjects()
    private let lock = OSAllocatedUnfairLock()

    private init() {
        #if canImport(UIKit)
        _ = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #endif
    }

    private func handleMemoryWarning() {
        lock.lock()
        for case let handler as MTIMemoryWarningHandling in handlers.allObjects {
            handler.handleMemoryWarning()
        }
        lock.unlock()
    }

    public static func addMemoryWarningHandler(_ memoryWarningHandler: MTIMemoryWarningHandling) {
        sharedObserver.lock.lock()
        sharedObserver.handlers.add(memoryWarningHandler)
        sharedObserver.lock.unlock()
    }

    public static func removeMemoryWarningHandler(_ memoryWarningHandler: MTIMemoryWarningHandling) {
        sharedObserver.lock.lock()
        sharedObserver.handlers.remove(memoryWarningHandler)
        sharedObserver.lock.unlock()
    }
}
