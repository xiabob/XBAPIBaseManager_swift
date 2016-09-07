//
//  XBAPIBaseManager.swift
//  XBAPIBaseManager_swift
//
//  Created by xiabob on 16/9/6.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import Foundation
import Alamofire

//MARK: - XBAPIManagerDataSource

public protocol XBAPIManagerDataSource: NSObjectProtocol {
    func parametersForApi(api: XBAPIBaseManager) -> [String: AnyObject]?
}


//MARK: - XBAPIManagerCallBackDelegate

/**
 *  接口请求结束回调协议
 */
public protocol XBAPIManagerCallBackDelegate: NSObjectProtocol {
    func onManagerCallApiSuccess(manager: XBAPIBaseManager)
    func onManagerCallApiFailed(manager: XBAPIBaseManager)
    func onManagerCallCancled(manager: XBAPIBaseManager)
}


public typealias CompletionHandler = (manager: XBAPIBaseManager) -> Void

private var kXBLocalUserDefaultsName = "com.xiabob.apiManager.localCache"
private var kXBDefaultMaxLocalDataCount = 500

//MARK: - XBAPIBaseManager
public class XBAPIBaseManager: NSObject {
    //MARK: - Properties
    public weak var delegate: XBAPIManagerCallBackDelegate? //回调delegate
    public weak var dataSource: XBAPIManagerDataSource?     //dataSource
    
    public var errorCode = Error() //错误码
    public var rawResponseString: String? //返回的原始字符串数据
    public var requestUrlString = "" //接口请求的url字符串
    public var timeout: Double = 15 { //每个接口可以单独设置超时时间，默认是15秒
        didSet {
            manager.session.configuration.timeoutIntervalForRequest = timeout
        }
    }
    
    
    private weak var apiManager: ManagerProtocol? //遵循ManagerProtocol的子类
    private lazy var manager: Manager = { //Manager对象实例，执行具体的网络请求工作
        let manager: Manager = Manager.sharedInstance
        manager.session.configuration.HTTPAdditionalHeaders?.updateValue("application/json; charset=UTF-8", forKey: "Accept")
        manager.session.configuration.HTTPAdditionalHeaders?.updateValue("application/json; charset=UTF-8", forKey: "Content-Type")
        manager.session.configuration.timeoutIntervalForRequest = self.timeout
        return manager
    }()
    private var taskTable = Dictionary<String, NSURLSessionTask>() //请求表
    private var currentRequest: Request? //当前请求
    private var completionHandler: CompletionHandler? //请求结束回调closure对象
    private lazy var userDefaults: NSUserDefaults? = { //用于缓存到本地
        let userDefaults = NSUserDefaults(suiteName: kXBLocalUserDefaultsName)
        if userDefaults?.dictionaryRepresentation().keys.count > kXBDefaultMaxLocalDataCount {
            userDefaults?.removePersistentDomainForName(kXBLocalUserDefaultsName)
        }
        return userDefaults
    }()
    
    private var parseQueue = dispatch_queue_create("com.xiabob.apiManager.parseData", DISPATCH_QUEUE_CONCURRENT)
    
    //MARK: -  lifecycle
    override init() {
        super.init()
        
        if self is ManagerProtocol {
            self.apiManager = self as? ManagerProtocol
            if let apiManager = apiManager {
                requestUrlString = apiManager.baseUrl + apiManager.path
            }
        } else {
            fatalError("child class must confirm ManagerProtocol!")
        }
    }
    
    convenience init(delegate: XBAPIManagerCallBackDelegate) {
        self.init()
        self.delegate = delegate
    }
    
    deinit {
        cancleRequests()
    }
    
    //MARK: - load data
    
    public func loadData() {
        executeHttpRequest()
    }
    
    public func loadData(completionHandler: CompletionHandler) {
        self.completionHandler = completionHandler
        loadData()
    }
    
    public func loadDataFromLocal() {
        guard let apiManager = apiManager else {return}
        if apiManager.shouldCache {
            guard let data = getDataFromLocal() else {return callOnManagerCallApiSuccess()} //只是没有数据
            handleRespnseData(data)
        } else {
            errorCode.code = .LoadLocalError
            callOnManagerCallApiFailed()
        }
    }
    
    public func loadDataFromLocal(completionHandler: CompletionHandler) {
        self.completionHandler = completionHandler
        loadDataFromLocal()
    }
    
    //MARK: - cancle operation
    
    public func cancleRequests() {
        for request in taskTable.values {
            request.cancel()
        }
        taskTable.removeAll()
    }
    
    public func cancleCurrentRequest() {
        if let currentRequest = currentRequest  {
            currentRequest.cancel()
            taskTable.removeValueForKey(String(currentRequest.task.taskIdentifier))
        }
    }
    
    //MARK: - private method
    private func executeHttpRequest() {
        guard let apiManager = apiManager else {return}
        //dataSource中设置参数其优先级更高
        let parameters = dataSource?.parametersForApi(self) ?? apiManager.parameters
        //转换为Alamofire的method
        let method = getMethod(apiManager.requestType)
        
        currentRequest = manager.request(method, requestUrlString, parameters: parameters).responseData { (response: Response<NSData, NSError>) in
            self.taskTable.removeValueForKey(String(self.currentRequest!.task.taskIdentifier))
            
            if let data = response.result.value {
                if apiManager.shouldCache {self.saveDataToLocal(data)}
                self.handleRespnseData(data)
            } else {
                self.handleError(response.result.error)
                debugPrint(response.result.error)
            }
        }
        taskTable.updateValue(currentRequest!.task, forKey: String(currentRequest!.task.taskIdentifier))
    }
    
    private func handleRespnseData(data: NSData) {
        guard let apiManager = apiManager else {return}
        
        rawResponseString = String(data: data, encoding: NSUTF8StringEncoding)
        
        var result: AnyObject = data
        if apiManager.isJsonData {
            do {
                result = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                onParseDataFail() //json数据解析出错
            }
        }
        
        dispatch_async(parseQueue) {
            //子线程中解析
            apiManager.parseResponseData(result)
            dispatch_async(dispatch_get_main_queue(), { //解析完成，回到主线程
                self.onCompleteParseData()
            })
        }
    }
    
    private func handleError(error: NSError?) {
        //取消请求特殊处理
        if error?.code == NSURLErrorCancelled {
            errorCode.code = .Cancle
            return callOnManagerCallCancled()
        }
        
        if error?.code >= 500 && error?.code < 600 {
            errorCode.code = .ServerError
            errorCode.message = error?.description
        } else {
            errorCode.code = .HttpError
            errorCode.message = error?.description
        }
        callOnManagerCallApiFailed()
    }
    
    private func getMethod(requestType: RequestType) -> Alamofire.Method {
        switch requestType {
        case .GET:
            return .GET
        case .POST:
            return .POST
        }
    }
    
    //MARK: - local cache
    
    private func saveDataToLocal(data: NSData) {
        userDefaults?.setObject(data, forKey: requestUrlString)
        userDefaults?.synchronize()
    }
    
    private func getDataFromLocal() -> NSData? {
        return userDefaults?.objectForKey(requestUrlString) as? NSData
    }
    
    public func deleteLocalCache() {
        userDefaults?.removePersistentDomainForName(kXBLocalUserDefaultsName)
    }
    
    //MARK:- 接口解析结束回调
    
    private func onCompleteParseData() {
        if errorCode.code == .Success {
            callOnManagerCallApiSuccess()
        } else {
            callOnManagerCallApiFailed()
        }
    }
    
    private func onParseDataFail() {
        errorCode.code = .ParseError
        callOnManagerCallApiFailed()
    }
    
    private func callOnManagerCallApiSuccess() {
        delegate?.onManagerCallApiSuccess(self)
        if let completionHandler = completionHandler {
            completionHandler(manager: self)
        }
    }
    
    private func callOnManagerCallApiFailed() {
        delegate?.onManagerCallApiFailed(self)
        if let completionHandler = completionHandler {
            completionHandler(manager: self)
        }
    }
    
    private func callOnManagerCallCancled() {
        delegate?.onManagerCallCancled(self)
        if let completionHandler = completionHandler {
            completionHandler(manager: self)
        }
    }
}
