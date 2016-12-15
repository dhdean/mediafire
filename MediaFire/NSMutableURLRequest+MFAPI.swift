//
//  NSMutableURLRequest+MFAPI.swift
//  MediaFire
//
//  Created by Daniel Dean on 12/12/16.
//

import Foundation

extension NSMutableURLRequest {
    
    public static func createMFAPIPost(version:Int, location: String, bodyData: NSData) -> NSMutableURLRequest {
        let url = "https://www.mediafire.com/api/1."+String(version)+"/"+location;
        let req = NSMutableURLRequest()
        req.HTTPMethod = "POST";
        req.HTTPBody = bodyData;
        req.URL = NSURL(string: url)
        return req;
    }
    
}