//
//  GetAppInfo.swift
//  XBAPIBaseManager_swift
//
//  Created by xiabob on 16/9/6.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit

class GetAppInfo: XBAPIBaseManager, ManagerProtocol {
    var baseUrl: String {return "https://itunes.apple.com"}
    var path: String {return "/lookup"}
    var parameters: [String : AnyObject]? {return ["id": "414478124" as AnyObject]}
    var shouldCache: Bool {return true}
    
    func parseResponseData(_ data: AnyObject) {
        print(rawResponseString!)
    }
    
}
