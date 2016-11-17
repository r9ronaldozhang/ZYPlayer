//
//  ViewController.swift
//  ZYPlayerDemo
//
//  Created by 张宇 on 2016/11/17.
//  Copyright © 2016年 成都拓尔思. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 将整个ZYPlayer文件夹拖拽到你的项目中即可，无其他依赖
        // 扩展或者调整UI，建议直接在xib中修改。
        // 总共代码精简在500行左右，如果想增加牛逼功能，请先阅读代码，注释已经不能再详细了
        
        // 注意：在使用前，请注意自己项目的部署关系，由于屏幕旋转需要手动进行，所以请参见demo内的ZYTabBarController的重新两个方法，将代码拷贝到你的rootViewController 中，并且按照注释进行简单配置
        // 这样无论你的项目是否支持横竖屏，播放器的旋转都不会有问题
        
        // 创建播放器的初始化方法
        let player = ZYPlayer(nibName: "ZYPlayer", bundle: nil, onView: self.view, orgFrame: CGRect(x: 0, y: 64, width: view.bounds.width, height: view.bounds.width*9/16) , url: "http://media.vtibet.com/masvod/public/2014/01/23/20140123_143bd4c1b14_r1_300k.mp4")
        // 下面是可选的属性设置
        player.fillMode = .resizeAspectFill
//        player.bgView = ... 
//        player.centerBtn ....
//        player.state (获取播放状态)
        
        // 特别注意: 当你需要切换其他界面的时候，请调用下面的方法，销毁播放器，避免内存泄漏
//        player.releasePlayer()
        
        view.addSubview(player.view)
        addChildViewController(player)
    }

}

