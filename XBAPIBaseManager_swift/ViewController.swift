//
//  ViewController.swift
//  XBAPIBaseManager_swift
//
//  Created by xiabob on 16/9/6.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit


class ViewController: UIViewController, XBAPIManagerCallBackDelegate, XBAPIManagerDataSource {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let ds: GetAppInfo = GetAppInfo(delegate: self)
        ds.dataSource = self
        ds.loadData()
//        ds.loadDataFromLocal()
    }
    
    //MARK: - XBAPIManagerCallBackDelegate
    func onManagerCallApiSuccess(manager: XBAPIBaseManager) {
        print("\(manager) success")
    }
    
    func onManagerCallApiFailed(manager: XBAPIBaseManager) {
        print("\(manager) failed: \(manager.errorCode.message)")
    }
    
    func onManagerCallCancled(manager: XBAPIBaseManager) {
        print("\(manager) cancled")
    }
    
    func parametersForApi(api: XBAPIBaseManager) -> [String : AnyObject]? {
        return ["id": "907002334"]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

