//
//  MTILock.swift
//  MetalPetal
//
//  Created by YuAo on 05/08/2017.
//

import Foundation
import os

public protocol MTILocking: NSLocking {
    func tryLock() -> Bool
}

private final class MTILock: NSObject, MTILocking {
    private let unfairLock = OSAllocatedUnfairLock()

    func lock() {
        unfairLock.lock()
    }

    func unlock() {
        unfairLock.unlock()
    }

    func tryLock() -> Bool {
        unfairLock.lockIfAvailable()
    }
}

/// Create a non-recursive lock. Unlocking a lock from a different thread other than the locking thread can
/// result in undefined behavior.
public func MTILockCreate() -> MTILocking {
    MTILock()
}
