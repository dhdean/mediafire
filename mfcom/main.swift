//
//  main.swift
//  mfcom
//
//  Created by Daniel Dean on 12/13/16.
//

import Foundation

let client:MFClient = MFClient(appID: "<APP ID HERE>", apiKey: "<API KEY HERE>", maxQueuedJobs: 10)
let sema = dispatch_semaphore_create(0)
client.getSessionToken("<EMAIL HERE>", password: "<PASSWORD HERE>", handler: { (err) in
    if (err != nil) {
        print("%@", err)
        dispatch_semaphore_signal(sema)
        return
    }
    client.sessionPost("folder", action:"get_info", query:[:]) { (response, error) in
        print("%@",response)
        dispatch_semaphore_signal(sema)
    }
})
dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER)