//
//  MFClient.swift
//
//  Created by Daniel Dean on 12/11/16.
//

import Foundation

typealias TokenCallback = (NSString?) -> Void


/**
 ///////////////////////////////////////////////////////////////////////////////
 MFSessionToken
 ///////////////////////////////////////////////////////////////////////////////
 */
class MFSessionToken {
    var token:String?
    var expiresOn:Date?
    var lock:NSLock
    
    init() {
        self.lock = NSLock()
    }
    
    /**
     - returns: The current token value.
     */
    func value() -> String {
        self.lock.lock()
        var token:String? = self.token
        if Date().compare(self.expiresOn!) == ComparisonResult.orderedDescending {
            token = nil
        }
        self.lock.unlock()
        return token!
    }
    
    /**
     - returns: True if the current token has 2 minutes or less remaining.
     */
    func willExpireSoon() -> Bool {
        var willExpire = false
        self.lock.lock()
        if self.expiresOn != nil {
            willExpire = (self.expiresOn!.addingTimeInterval(120) as NSDate).isGreaterThan(self.expiresOn)
        }
        self.lock.unlock()
        return willExpire
    }
    
    /**
     Sets the current token value
     
     - param token: The value to be set.
     */
    func setValue(_ token: String) -> Void {
        self.lock.lock()
        if self.token != token {
            self.token = token
            self.expiresOn = Date().addingTimeInterval(540)
        }
        self.lock.unlock()
    }
    
    /**
     Clears the current value and resets the token.
     */
    func clear() -> Void {
        self.lock.lock()
        self.token = nil
        self.expiresOn = nil
        self.lock.unlock()
    }

}


/**
 ///////////////////////////////////////////////////////////////////////////////
 MFReqHandle
 ///////////////////////////////////////////////////////////////////////////////
 */
open class MFReqHandle {
    var apiReq:JAPIReq?
    var task:URLSessionDataTask?
    
    init(_ apiReq:JAPIReq) {
        self.apiReq = apiReq
    }
}


/**
 ///////////////////////////////////////////////////////////////////////////////
 NSError+MFClient
 ///////////////////////////////////////////////////////////////////////////////
 */
public extension NSError {
    public func isInvalidSessionTokenError() -> Bool {
        return (self.domain == errDomain) && (self.code == 949)
    }
    
    public static func invalidSessionToken() -> NSError {
        return NSError.mfClientError(949, userInfo: nil)
    }

    public static func emptySessionToken() -> NSError {
        return NSError.mfClientError(5, userInfo: nil)
    }

    public static func apiClientQueueFull() -> NSError {
        return NSError.mfClientError(990, userInfo: nil)
    }

    public static func clientNotAuthorizedYet() -> NSError {
        return NSError.mfClientError(45, userInfo: nil)
    }

    public static func mfClientError(_ code: Int, userInfo: Dictionary<String,AnyObject>?) -> NSError {
        return NSError(domain: errDomain, code: code, userInfo: userInfo)
    }
}


/**
 ///////////////////////////////////////////////////////////////////////////////
 MFClientConfig
 ///////////////////////////////////////////////////////////////////////////////
 */
open class MFClientConfig {
    open var appID:String?
    open var apiKey:String?
    open var maxQueuedJobs:Int = 1
    open var apiVersion:Int = 5
    open var persistSession:Bool = false
}


/**
 ///////////////////////////////////////////////////////////////////////////////
 MFClient
 ///////////////////////////////////////////////////////////////////////////////
 */
public protocol MFClientDelegate: class {
    func clientDidRequestLoginCredentials()
}

public typealias CallbackWithError = (NSError?) -> Void
public typealias CallbackWithDictionary = (NSDictionary?, NSError?) -> Void

let errDomain:String = "net.dhdean.mediafire"
let apiDomain:String = "www.mediafire.com"

open class MFClient: JAPIClient {
    
    open weak var delegate:MFClientDelegate?
    
    var sessionToken:MFSessionToken
    var config:MFClientConfig
    var jobs:SynchronizedQueue?
    var waitingForToken:SynchronizedBool = SynchronizedBool(value: false)
    
    init(config:MFClientConfig) {
        self.config = config
        self.sessionToken = MFSessionToken()
        self.jobs = SynchronizedQueue(maxSize: config.maxQueuedJobs)
    }
    
    
    /**
     Acquires a session token and saves it for usage on future API requests.
     
     - param email: The email address of the user account.
     - param password: The password of the user account.
     - param handler: The completion handler fired when the request completes.
     */
    open func getSessionToken(_ email: String, password: String, handler: @escaping CallbackWithError) -> Void {
        if !self.waitingForToken.makeTrue() {
            handler(NSError.clientNotAuthorizedYet())
            return
        }
        
        var creds = [String:String]()
        creds["signature"] = (email+password+self.config.appID!+self.config.apiKey!).sha1()
        creds["email"] = email
        creds["password"] = password
        creds["application_id"] = self.config.appID
        
        self.post("user", action: "get_session_token", query: creds, handler: { (response: Dictionary<String,AnyObject>?, error: NSError?) in
            let workingResponse:Dictionary<String,AnyObject>? = response ?? [String:AnyObject]()
            let innerResponse:AnyObject = workingResponse!["response"] as AnyObject
            let token = innerResponse["session_token"]
            let tokenString = token as? String
            if (tokenString == nil || tokenString!.isEmpty) {
                self.waitingForToken.makeFalse()
                handler(NSError.emptySessionToken())
            }
            self.sessionToken.setValue(tokenString!)
            self.waitingForToken.makeFalse()
            handler(nil)
        })
    }

    /**
     Requests a new session token by using the existing token.
     
     - param handler: The completion handler fired when the request completes.
     */
    func renewSessionToken(_ handler: @escaping CallbackWithError) -> Void {
        if !self.waitingForToken.makeTrue() {
            return
        }
        self.post("user", action: "renew_session_token", query: [:]) { (response: Dictionary<String,AnyObject>?, error: NSError?) in
            handler(nil)
        }
    }
   
    /**
     Queues a request for sending.
     
     - param apiReq: The request configuration.
     - param handler: The completion handler fired when the request completes.
     
     - returns: A handle containing the original request object and a data task
     */
    @discardableResult
    open func sessionPost(_ apiReq: JAPIReq, handler: @escaping JAPICallback) -> MFReqHandle? {
        let handle = MFReqHandle(apiReq)
        if !(self.jobs!.enqueue(handle)) {
            handler(nil, NSError.apiClientQueueFull())
            return nil
        }
        let tokenString:String? = self.sessionToken.value()
        if (tokenString == nil || tokenString!.isEmpty) {
            handler(nil,NSError(domain: errDomain, code: 7, userInfo: nil))
            return nil
        }
        if (self.config.persistSession && self.sessionToken.willExpireSoon()) {
            DispatchQueue.global(qos: .default).async(execute: {
                self.renewSessionToken({ (error) in
                    // Don't do anything in this case, this is a passive call.
                })
            })
        }
        apiReq.query["session_token"] = self.sessionToken.value()
        return self.post(apiReq.api!, action: apiReq.action!, query: apiReq.query) {(response, error) in
            if (error != nil && error!.isInvalidSessionTokenError()) {
                self.jobs?.enqueue(apiReq)
                self.delegate?.clientDidRequestLoginCredentials()
                return
            }
            handler(response, error)
        }
    }
    
    /**
     Queues a request for sending.
     
     - param api: The api group.
     - param action: The api action.
     - param query: The query parameters for the request.
     - param handler: The completion handler fired when the request completes.
     
     - returns: A handle containing the original request object and a data task
     */
    @discardableResult
    open func sessionPost(_ api: String, action: String, query: Dictionary<String, String>?, handler: @escaping JAPICallback) -> MFReqHandle? {
        let req = JAPIReq()
        req.api = api
        req.action = action
        if (query != nil) {
            req.query = query!
        }
        return self.sessionPost(req, handler: handler)
    }
    
    /**
     Executes a request immediately.
     
     - param api: The API module for the request.
     - param action: The API action for the request.
     - param query: The query parameters as a collection of key/value pairs
     - param handler: The completion handler fired when the request completes.
     
     - returns: A handle containing the original request object and a data task
     */
    @discardableResult
    open func post(_ api: String, action: String, query: Dictionary<String, String>, handler: @escaping JAPICallback) -> MFReqHandle {
        var mutableQuery = query
        mutableQuery["response_format"] = "json"
        let apiReq = JAPIReq()
        apiReq.api = api
        apiReq.action = action
        apiReq.query = mutableQuery
        apiReq.method = "POST"
        
        let handle = MFReqHandle(apiReq)
        handle.task = self.dispatch(apiReq, handler: handler)
        
        return handle
    }
    
   
    /**
     OVERRIDE of JAPIClient method.
     */
    override open func resolveUrl(_ apiReq: JAPIReq) -> String? {
        let location = apiReq.api!+"/"+apiReq.action!+".php"
        let url = "https://"+apiDomain+"/api/1."+String(self.config.apiVersion)+"/"+location
        return url
    }
    
    /**
     OVERRIDE of JAPIClient method.  The MediaFire API returns valid JSON on 
     some non-200 codes.
     */
    override open func evaluateStatusCode(_ code: Int, responseData: Data?) -> NSError? {
        return nil
    }
  
}
