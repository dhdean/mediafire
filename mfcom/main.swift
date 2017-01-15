//
//  main.swift
//  mfcom
//
//  Created by Daniel Dean on 12/13/16.
//

import Foundation

let config = MFClientConfig()

config.appID = "<APP ID HERE>"
config.apiKey = "<API KEY HERE>"
config.maxQueuedJobs = 10
config.apiVersion = 5
config.persistSession = false


let client:MFClient = MFClient(config: config)
let sema = DispatchSemaphore(value: 0)
client.getSessionToken("<EMAIL HERE>", password: "<PASSWORD HERE>", handler: { (err) in
    if let localErr = err {
        print("%@", localErr)
        sema.signal()
        return
    }
    var req = JAPIReq()
    req.api = "folder"
    req.action = "get_info"
    client.sessionPost(req) { (response, error) in
        print("%@",response ?? "")
        sema.signal()
    }
})
sema.wait(timeout: DispatchTime.distantFuture)
