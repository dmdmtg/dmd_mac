//
//  DeQueue.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/23/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Foundation

//
// A very simple double-ended queue of bytes.
//
public struct ByteQueue {
    private var array = [UInt8]()
    
    public var isEmpty: Bool {
        return array.isEmpty
    }
    
    public var count: Int {
        return array.count
    }
    
    public mutating func pushFront(b: UInt8) {
        array.insert(b, at: 0)
    }
    
    public mutating func popBack() -> UInt8? {
        if array.isEmpty {
            return nil
        } else {
            return array.removeLast()
        }
    }
}
