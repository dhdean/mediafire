//
//  SynchronizedQueue.swift
//  MediaFire
//
//  Created by Daniel Dean on 12/14/16.
//  Copyright © 2016 dhdean. All rights reserved.
//

import Foundation

class SynchronizedQueue {
    let queue:NSMutableArray = NSMutableArray()
    var lock:NSLock
    var maxSize:Int = 1
    
    //--------------------------------------------------------------------------
    init(maxSize:Int) {
        self.maxSize = maxSize
        self.lock = NSLock()
    }
    
    //--------------------------------------------------------------------------
    func enqueue(obj:AnyObject) -> Bool {
        var result = true
        self.lock.lock()
        if self.queue.count >= self.maxSize {
            result = false
        }
        self.queue.insertObject(obj, atIndex: 0)
        self.lock.unlock()
        return result
    }
    
    //--------------------------------------------------------------------------
    func dequeue() -> AnyObject? {
        self.lock.lock()
        if (self.queue.count == 0) {
            self.lock.unlock()
            return nil
        }
        let result:AnyObject = self.queue.lastObject!
        self.queue.removeLastObject()
        self.lock.unlock()
        return result
    }
    
}