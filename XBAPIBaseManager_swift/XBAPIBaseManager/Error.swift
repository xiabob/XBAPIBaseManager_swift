//
//  Error.swift
//  XBAPIBaseManager_swift
//
//  Created by xiabob on 16/9/6.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import Foundation

public struct Error {
    public enum Code: Int {
        case Success = 0 //请求成功，返回数据正确
        case ParametersError //请求的参数错误
        case LoadLocalError //加载本地缓存数据时出错
        case HttpError //网络请求成功，返回出错
        case ParseError //解析返回的数据出错
        case Cancle //请求取消
        case Timeout //请求超时
        case NoNetWork //没有网络
        case ServerError //服务器异常
    }
    
    /// 错误码
    public var code = Code.Success
    /// 具体错误信息
    public var message: String?
    
    public init(code: Code = .Success, errorMessage message: String? = nil) {
        self.code = code
        self.message = message
    }
}
