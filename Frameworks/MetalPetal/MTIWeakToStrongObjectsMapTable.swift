//
//  MTIWeakToStrongObjectsMapTable.swift
//  MetalPetal
//
//  Created by YuAo on 16/07/2017.
//

import Foundation
import ObjectiveC

// 1024 x 64 x 8 (byte size of a pointer) = 512K
private let MTIWeakToStrongObjectsMapTableCompactThreshold = 1024 * 64

/// Behaves like NSMapTable with key options: NSMapTableObjectPointerPersonality|NSMapTableWeakMemory, value
/// options: NSMapTableStrongMemory. Entries are purged right away when the weak key is reclaimed.
public final class MTIWeakToStrongObjectsMapTable<KeyType: AnyObject, ObjectType: AnyObject> {
    private let items = NSPointerArray(options: [.weakMemory, .objectPointerPersonality])
    private var compactableItemCount = 0

    // Safe to use `self`'s address as the association key, since we remove all the associations on deallocation.
    private var associationKey: UnsafeRawPointer {
        UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    public init() {}

    deinit {
        removeAllObjects()
    }

    public func object(forKey key: KeyType) -> ObjectType? {
        objc_getAssociatedObject(key, associationKey) as? ObjectType
    }

    public func setObject(_ object: ObjectType?, forKey key: KeyType) {
        objc_setAssociatedObject(key, associationKey, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if object != nil {
            items.addPointer(Unmanaged.passUnretained(key).toOpaque())
            compactableItemCount += 1
            if compactableItemCount >= MTIWeakToStrongObjectsMapTableCompactThreshold {
                compact()
            }
        } else {
            compact()
            let keyPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(key).toOpaque())
            var index = NSNotFound
            for i in 0 ..< items.count where items.pointer(at: i) == keyPointer {
                index = i
                break
            }
            if index != NSNotFound {
                items.removePointer(at: index)
            }
        }
    }

    public func removeObject(forKey key: KeyType) {
        setObject(nil, forKey: key)
    }

    public func removeAllObjects() {
        compact()
        for key in items.allObjects {
            objc_setAssociatedObject(key, associationKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        items.count = 0
    }

    public func compact() {
        // http://www.openradar.me/15396578
        // https://stackoverflow.com/questions/31322290/nspointerarray-weird-compaction
        items.addPointer(nil)
        items.compact()
        compactableItemCount = 0
    }
}
