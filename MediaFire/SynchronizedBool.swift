//
//  SynchronizedBool.swift
//  MediaFire
//
//  Created by Daniel Dean on 12/14/16.
//  Copyright © 2016 dhdean. All rights reserved.
//

import Foundation

public class SynchronizedBool {
    let lock = NSLock()
    var boolie = false
    
    //--------------------------------------------------------------------------
    init(value:Bool) {
        self.boolie = value
    }
    
    //--------------------------------------------------------------------------
    public func value() -> Bool {
        self.lock.lock()
        let val = self.boolie
        self.lock.unlock()
        return val
    }
    
    //--------------------------------------------------------------------------
    public func makeTrue () -> Bool {
        var changed = true
        self.lock.lock()
        if (self.boolie) {
            // value was already true
            changed = false
        }
        self.boolie = true
        self.lock.unlock()
        return changed
    }
    
    //--------------------------------------------------------------------------
    public func makeFalse () -> Bool {
        var changed = true
        self.lock.lock()
        if (!self.boolie) {
            // value was already false
            changed = false
        }
        self.boolie = false
        self.lock.unlock()
        return changed
    }
    
    
}