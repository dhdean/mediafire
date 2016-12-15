//
//  MFClient.swift
//  MediaFire
//
//  Created by Daniel Dean on 12/11/16.
//

import Foundation

typealias TokenCallback = (NSString?) -> Void

////////////////////////////////////////////////////////////////////////////////
// SessionToken
////////////////////////////////////////////////////////////////////////////////

class SessionToken {
    var token:String?
    var expiresOn:NSDate?
    var lock:NSLock
    
    //--------------------------------------------------------------------------
    init() {
        self.lock = NSLock()
    }
    
    //--------------------------------------------------------------------------
    func value() -> String {
        self.lock.lock()
        var token:String? = self.token
        if NSDate().compare(self.expiresOn!) == NSComparisonResult.OrderedDescending {
            token = nil
        }
        self.lock.unlock()
        return token!
    }
    
    //--------------------------------------------------------------------------
    func setValue(token: String) {
        self.lock.lock()
        self.token = token
        self.expiresOn = NSDate().dateByAddingTimeInterval(360)
        self.lock.unlock()
    }
    
    //--------------------------------------------------------------------------
    func clear() {
        self.lock.lock()
        self.token = nil
        self.expiresOn = nil
        self.lock.unlock()
    }

}

////////////////////////////////////////////////////////////////////////////////
// MFClient
////////////////////////////////////////////////////////////////////////////////


public typealias CallbackWithError = (NSError?) -> Void
public typealias CallbackWithDictionary = (NSDictionary?, NSError?) -> Void

let errDomain:String = "net.dhdean.mediafire"

public class MFClient {
    
    var sessionToken:SessionToken
    var appID:String?
    var apiKey:String?
    var session:NSURLSession?
    var jobs:SynchronizedQueue?
    var waitingForToken:SynchronizedBool = SynchronizedBool(value: false)
    var apiVersion:Int = 5
    
    //--------------------------------------------------------------------------
    init(appID: String, apiKey: String, maxQueuedJobs: Int, apiVersion:Int = 5) {
        self.appID = appID
        self.apiKey = apiKey
        self.sessionToken = SessionToken()
        self.jobs = SynchronizedQueue(maxSize: maxQueuedJobs)
    }
    
    //--------------------------------------------------------------------------
    func urlSession() -> NSURLSession? {
        if (self.session == nil) {
            return NSURLSession.sharedSession()
        }
        return self.session
    }
    
    //--------------------------------------------------------------------------
    public func getSessionToken(email: String, password: String, handler:CallbackWithError) {
        if !self.waitingForToken.makeTrue() {
            handler(NSError(domain: errDomain, code: 45, userInfo: nil))
            return
        }
        let mutableCreds = NSMutableDictionary()
        mutableCreds["signature"] = (email+password+self.appID!+self.apiKey!).sha1()
        mutableCreds["email"] = email
        mutableCreds["password"] = password
        mutableCreds["application_id"] = self.appID
        self.post("user", action: "get_session_token", query: mutableCreds, handler: { (response, error) in
            let token = response!["response"]!["session_token"]
            let tokenString = token as? String
            if (tokenString == nil || tokenString!.isEmpty) {
                self.waitingForToken.makeFalse()
                handler(NSError(domain: errDomain, code: 5, userInfo: nil))
            }
            self.sessionToken.setValue(tokenString!)
            self.waitingForToken.makeFalse()
            handler(nil)
        })
    }

   
    //--------------------------------------------------------------------------
    public func sessionPost(api: String, action: String, query: NSMutableDictionary, handler: CallbackWithDictionary) -> NSURLSessionTask? {
        let tokenString:String? = self.sessionToken.value()
        if (tokenString == nil || tokenString!.isEmpty) {
            handler(nil,NSError(domain: errDomain, code: 7, userInfo: nil))
            return nil
        }
        query["session_token"] = self.sessionToken.value()
        return self.post(api, action: action, query: query, handler: handler)
    }
    
    //--------------------------------------------------------------------------
    public func post(api: String, action: String, query: NSMutableDictionary, handler: CallbackWithDictionary) -> NSURLSessionTask? {
        query["response_format"] = "json"
        let data = query.stringifyAsURLParams(true).dataUsingEncoding(NSUTF8StringEncoding)!
        let location = self.location(api, action: action)
        return self.post(location, query: data, handler: handler)
    }
    
    //--------------------------------------------------------------------------
    public func post(location: String, query: NSData, handler: CallbackWithDictionary) -> NSURLSessionTask {
        let req = NSMutableURLRequest.createMFAPIPost(self.apiVersion, location: location, bodyData: query)
        let task = self.urlSession()?.dataTaskWithRequest(req, completionHandler: { (data, response, error) in
            if (error != nil) {
                handler(nil, NSError(domain: (error?.domain)!, code: (error?.code)!, userInfo: ["response": data ?? ""]))
                return
            }
            
            var jsonDict:NSDictionary?
            do {
                try jsonDict = data!.jsonDataAsDictionary()
            } catch let jsonErr as NSError  {
                handler(nil, NSError(domain:jsonErr.domain, code:jsonErr.code, userInfo:["response": data ?? ""]))
                return;
            }
            
            handler(jsonDict, nil)
        })
        task?.resume()
        return task!
    }
    
    //--------------------------------------------------------------------------
    func location(api: String, action: String) -> String {
        return api+"/"+action+".php"
    }
    
}