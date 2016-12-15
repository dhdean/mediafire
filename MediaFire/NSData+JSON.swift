//
//  NSData+JSON.swift
//  MediaFire
//
//  Created by Daniel Dean on 12/14/16.
//  Copyright © 2016 dhdean. All rights reserved.
//

import Foundation

extension NSData {
    
    public func jsonDataAsDictionary() throws -> NSDictionary? {
        var jsonDict:NSDictionary?
        do {
            let jsonObject = try NSJSONSerialization.JSONObjectWithData(self, options: NSJSONReadingOptions.MutableContainers)
            jsonDict = jsonObject as? NSDictionary
        } catch let jsonErr as NSError  {
            throw jsonErr
        }
        if (jsonDict == nil) {
            throw NSError(domain: "", code: 99, userInfo: nil)
        }
        return jsonDict
    }

}