//
//  NSDictionary+Stringify.swift
//  MediaFire
//
//  Created by Daniel Dean on 12/13/16.
//

import Foundation

extension NSDictionary {
    
    public func stringifyAsURLParams(urlEncode: Bool) -> String {
        var query = String()
        var firstItem = true;
        for (key, value) in self {
            if (!(key is String) || !(value is String)) {
                continue
            }
            var encoded:String? = value as? String
            if (urlEncode) {
                encoded = encoded?.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())
            }
            if (!firstItem) {
                query += "&"
            } else {
                firstItem = false
            }
            query += (key as! String) + "=" + encoded!
        }
        return query as String
    }
}