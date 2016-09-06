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
    func onManagerCallApiSuccess(mnamager: XBAPIBaseManager)
    func onManagerCallApiFailed(manager: XBAPIBaseManager)
    func onManagerCallCancled(manager: XBAPIBaseManager)
}


//MARK: - XBAPIBaseManager
public class XBAPIBaseManager: NSObject {
    public weak var delegate: XBAPIManagerCallBackDelegate?
    public weak var dataSource: XBAPIManagerDataSource?
    
    public var errorCode = Error() //错误码
    public var rawResponseString: String? //返回的原始字符串数据
    public var requestUrlString = "" //接口请求的url字符串
    public var timeout: Double = 15 { //每个接口可以单独设置超时时间，默认是15秒
        didSet {
            manager.session.configuration.timeoutIntervalForRequest = timeout
        }
    }
    
    private weak var apiManager: ManagerProtocol?
    private lazy var manager: Manager = {
        let manager: Manager = Manager.sharedInstance
//        manager.session.configuration.HTTPAdditionalHeaders?.updateValue("application/json; charset=UTF-8", forKey: "Accept")
//        manager.session.configuration.HTTPAdditionalHeaders?.updateValue("application/json; charset=UTF-8", forKey: "Content-Type")
        manager.session.configuration.timeoutIntervalForRequest = self.timeout
        return manager
    }()
    
    private lazy var parseQueue: dispatch_queue_t = {
        return dispatch_queue_create("com.xiabob.apiManager.parseData", DISPATCH_QUEUE_CONCURRENT)
    }()
    
    //MARK: -  init life cycle
    override init() {
        super.init()
        
        if self is ManagerProtocol {
            self.apiManager = self as? ManagerProtocol
        } else {
            fatalError("child class must confirm ManagerProtocol!")
        }
    }
    
    convenience init(delegate: XBAPIManagerCallBackDelegate) {
        self.init()
        self.delegate = delegate
    }
    
    public func loadData() {
        executeHttpRequest()
    }
    
    //MARK: - private method
    private func executeHttpRequest() {
        guard let apiManager = apiManager else {return}
        //拼接完整url
        let urlString = apiManager.baseUrl + apiManager.path
        requestUrlString = urlString
        //dataSource中设置参数其优先级更高
        let parameters = dataSource?.parametersForApi(self) ?? apiManager.parameters
        //转换为Alamofire的method
        let method = getMethod(apiManager.requestType)
        manager.request(method, urlString, parameters: parameters)
               .responseJSON { (response) in
                if let value = response.result.value {
                    self.handleRespnseData(response)
                    debugPrint(value)
                } else {
                    self.handleError(response.result.error)
                    debugPrint(response.result.error)
                }
        }
    }
    
    private func handleRespnseData(response: Alamofire.Response<AnyObject, NSError>) {
        if let data = response.data {
            rawResponseString = String(data: data, encoding: NSUTF8StringEncoding)
        }
        
        dispatch_async(parseQueue) {
            //子线程中解析
            self.apiManager?.parseResponseData(response.result.value)
            dispatch_async(dispatch_get_main_queue(), { //解析完成，回到主线程
                self.onCompleteParseData()
            })
        }
    }
    
    private func handleError(error: NSError?) {
        if error?.code == NSURLErrorCancelled {
            errorCode.code = .Cancle
            return
        }
        
        if error?.code >= 500 && error?.code < 600 {
            errorCode.code = .ServerError
            errorCode.message = error?.description
        } else {
            errorCode.code = .HttpError
            errorCode.message = error?.description
        }
    }
    
    private func onCompleteParseData() {
        if let delegate = self.delegate {
            if errorCode.code == .Success {
                delegate.onManagerCallApiSuccess(self)
            } else {
                delegate.onManagerCallApiFailed(self)
            }
        }
    }
    
    private func getMethod(requestType: RequestType) -> Alamofire.Method {
        switch requestType {
        case .GET:
            return .GET
        case .POST:
            return .POST
        }
    }
}
