//
//  ViewController.swift
//  XBAPIBaseManager_swift
//
//  Created by xiabob on 16/9/6.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit


class ViewController: UIViewController, XBAPIManagerCallBackDelegate, XBAPIManagerDataSource {
    private var chain = XBAPIChain()
    let ds1 = GetAppInfo()
    let ds2 = GetAppInfo()
    let ds3 = GetAppInfo()
    let ds4 = GetAppInfo()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        let ds: GetAppInfo = GetAppInfo(delegate: self)
//        ds.dataSource = self
//        ds.loadData()
////        ds.loadDataFromLocal()
        
        ds1.dataSource = self
        ds2.dataSource = self
        ds3.dataSource = self
        ds4.dataSource = self
        debugPrint("\(ds1),\(ds2),\(ds3),\(ds4)")
        
        let _ = chain
            .load(api: ds1) { manager in
                debugPrint("\(manager)")
            }
            .next(api: ds2) { manager in
                debugPrint("\(manager)")
            }
            .next(api: ds3) { manager in
                debugPrint("\(manager)")
            }
            .next(api: ds4) { manager in
                debugPrint("\(manager)")
        }
    }
    
    //MARK: - XBAPIManagerCallBackDelegate
    func onManagerCallApiSuccess(_ manager: XBAPIBaseManager) {
        print("\(manager) success")
    }
    
    func onManagerCallApiFailed(_ manager: XBAPIBaseManager) {
        print("\(manager) failed: \(manager.errorCode.message)")
    }
    
    func onManagerCallCancled(_ manager: XBAPIBaseManager) {
        print("\(manager) cancled")
    }
    
    func parametersForApi(_ api: XBAPIBaseManager) -> [String : AnyObject]? {
        if api == ds1 {
            return ["id": "907002334" as AnyObject]
        } else if api == ds2 {
            return ["id": "907002335" as AnyObject]
        } else if api == ds3 {
            return ["id": "907002336" as AnyObject]
        } else if api == ds4 {
            return ["id": "907002337" as AnyObject]
        }
        
        return ["id": "907002334" as AnyObject]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

