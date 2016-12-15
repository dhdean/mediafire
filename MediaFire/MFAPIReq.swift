//
//  MFAPIReq.swift
//  MediaFire
//
//  Created by Daniel Dean on 12/14/16.
//  Copyright © 2016 dhdean. All rights reserved.
//

import Foundation

public class MFAPIReq {
    
    public var api:String? = ""
    public var action:String? = ""
    public var query:NSDictionary? = nil
    public var callback:CallbackWithDictionary?
    public var task:NSURLSessionDataTask? = nil
    
}