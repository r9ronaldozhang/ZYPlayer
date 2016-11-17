//
//  ZYTabBarController.swift
//  ZYPlayerDemo
//
//  Created by 张宇 on 2016/11/17.
//  Copyright © 2016年 成都拓尔思. All rights reserved.
//

import UIKit

class ZYTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }

    
    /********* 指定某些具体的控制器不能自动旋转 **********/
    
    override var shouldAutorotate: Bool {
        guard let nav = self.selectedViewController as? UINavigationController else {
            return true
        }
        // 填写播放器所在的类（注意命名空间） 加载这个控制器的时候，控制器就不会自动进行旋转  无视你项目部署的支持方向
        if (nav.topViewController?.isKind(of: NSClassFromString("ZYPlayerDemo.ViewController")!))! {
            return false
        }
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard let nav = self.selectedViewController as? UINavigationController else {
            return [.portrait, .landscapeLeft, .landscapeRight]
        }
        // 填写播放器所在的类（注意命名空间） 当加载这个控制器的时候，这个控制器就只支持竖屏 无视你项目部署的支持方向
        if (nav.topViewController?.isKind(of: NSClassFromString("ZYPlayerDemo.ViewController")!))! {
            return UIInterfaceOrientationMask.portrait
        }
        return [.portrait, .landscapeLeft, .landscapeRight]
    }
    /********* 指定某些具体的控制器不能自动旋转 **********/
    
}
