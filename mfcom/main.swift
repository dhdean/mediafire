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