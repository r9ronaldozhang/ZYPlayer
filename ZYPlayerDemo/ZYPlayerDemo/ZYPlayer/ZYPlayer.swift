//
//  ZYPlayer.swift
//  掌上遂宁
//
//  Created by 张宇 on 2016/11/14.
//  Copyright © 2016年 张宇. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

//播放器的几种状态
enum ZYPlayerState : Int {
    case buffering     = 1
    case playing       = 2
    case stopped       = 3
    case pause         = 4
}

// 播放器填充模式
enum ZYPlayerLayerFillMode : Int {
    case    resizeAspect     = 1
    case    resizeAspectFill = 2
    case    resize           = 3
}

class ZYPlayer: UIViewController {

    /** open property */
    
    /** 播放器的状态 */
    open var state                          : ZYPlayerState = .stopped
    /** 播放器的填充模式 */
    open var fillMode                       : ZYPlayerLayerFillMode = .resizeAspect
    /** 视频的总时长 */
    open var duration                       : CGFloat = 0
    /** 视频缓冲的进度 */
    open var bufferedProgress               : Float = 0
    /** 视频的播放进度 0~1 */
    open var progress                       : CGFloat = 0
    /** 视频当前播放的时间点 */
    open var current                        : CGFloat = 0
    
    /** xib property */
    
    @IBOutlet weak var bgView               : UIImageView!
    
    @IBOutlet weak var playerView           : UIView!
    
    @IBOutlet weak var controlBar           : UIView!
    
    @IBOutlet weak var playPauseBtn         : UIButton!
    
    @IBOutlet weak var fullBtn              : UIButton!
    
    @IBOutlet weak var totalDuration        : UILabel!
    
    @IBOutlet weak var currentDuration      : UILabel!
    
    @IBOutlet weak var indicator            : UIActivityIndicatorView!
    
    @IBOutlet weak var centerBtn            : UIButton!
    
    @IBOutlet weak var slider               : UISlider!
    
    @IBOutlet weak var progressView         : UIProgressView!
    /** 快进 快退 容器view */
    @IBOutlet weak var forwardView          : UIView!
    
    @IBOutlet weak var forwardImageView     : UIImageView!
    
    @IBOutlet weak var forwardLabel         : UILabel!
    
    
    /** private property */
    fileprivate var orgView                 : UIView?
    fileprivate var orgFrame                : CGRect?
    fileprivate var url                     : String?
    
    fileprivate var player                  : AVPlayer?
    fileprivate var playerItem              : AVPlayerItem?
    fileprivate var playerLayer             : AVPlayerLayer?
    
    fileprivate weak var durationTimer      : Timer?
    fileprivate weak var autoTimer          : Timer?
    fileprivate var sumTime                 : Float = 0
    fileprivate var isHorizontalMove        : Bool = false          // 标识pan手势是水平还是垂直
    
    /** 标识用户正在交互 */
    fileprivate var isInteraction           = false
    /** 上一次旋转时的屏幕方向 */
    fileprivate var lastOrientation         : UIDeviceOrientation?

    fileprivate var volumnSlider            : UISlider?
    
    fileprivate lazy var keyWindow          : UIWindow = {
        let keyWindow = UIApplication.shared.keyWindow
        keyWindow?.backgroundColor = UIColor.red
        return keyWindow!
    }()

    convenience init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?, onView orgView : UIView , orgFrame : CGRect, url : String) {
        self.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.orgView = orgView
        self.orgFrame = orgFrame
        self.url = url
        self.lastOrientation = .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.frame = orgFrame!
        // UI初始化
        initUI()
    }
    
    deinit {
        print("ZYPlayer deinit")
        releasePlayer()
    }
    
    // MARK: - 获取系统音量slider 
    fileprivate func getSystemVolumnSlider() -> UISlider? {
        if volumnSlider == nil {
            let mpVolumnView = MPVolumeView()
            for view in mpVolumnView.subviews {
                print(view.description)
                if view.bounds.height == 34 {   // MPVolumeSlider 的高度默认34
                    self.volumnSlider = view as? UISlider
                    break
                }
            }
            return volumnSlider
        }
        return volumnSlider
    }
    
    // MARK: - 交互处理
    @IBAction func playPauseButtonClick() {
        playPauseBtn.isSelected ? pauseToPlay() : startToPlay()
    }
    
    @IBAction func fullScreenButtonClick() {
        fullBtn.isSelected ? rotateToPortrait() : rotateToLandscapeLeft()
    }
    
    @IBAction func replayButtonClick() {
        // 重新初始化播放器
        initPlayer(url!)
        centerBtn.isHidden = true
    }
}

// MARK: - 初始化播放器
extension ZYPlayer  {
    fileprivate func initPlayer(_ url : String) {
        /** 先进行一次release */
        releasePlayer()
        // 添加通知监听
        addNotificationObserver()
        // 初始化avplayer 本身
        playerItem = AVPlayerItem(url: URL(string: url)!)
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = playerView.bounds
        playerView.layer.insertSublayer(playerLayer!, at: 0)
        switch fillMode {
        case .resizeAspect:
            playerLayer?.videoGravity = AVLayerVideoGravityResizeAspect
        case .resizeAspectFill:
            playerLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        case .resize:
            playerLayer?.videoGravity = AVLayerVideoGravityResize
        }
        // 添加KVO监听  必须要在创建了item以后才能监听KVO
        addKVOObserver()
        // 增加tap手势，控制controlBar显示与隐藏
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.playerViewDidTap))
        playerView.addGestureRecognizer(tap)
        // 添加pan手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.playerViewDidPan(pan:)))
        playerView.addGestureRecognizer(pan)
    }
}

// MARK: - 初始化UI
extension ZYPlayer {
    fileprivate func initUI() {
        indicator.isHidden = true
        playerView.backgroundColor = UIColor.black.withAlphaComponent(0.01)
        slider.setThumbImage(UIImage(named:"thumbImage.png"), for: .normal)
        slider.setThumbImage(UIImage(named:"thumbImage.png"), for: .highlighted)
        // slider 监听
        slider.addTarget(self, action: #selector(self.sliderIsSlipping(slider:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(self.sliderDidChanged(slider:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(self.sliderDidChanged(slider:)), for: .touchUpOutside)
        slider.addTarget(self, action: #selector(self.sliderDidChanged(slider:)), for: .touchCancel)
    }
}

// MARK: - 播放slider处理
extension ZYPlayer {
    @objc fileprivate func sliderIsSlipping(slider : UISlider) {
        isInteraction = true
        durationTimer?.invalidate()
        autoTimer?.invalidate()
        currentDuration.text = timeFormate(time: duration * CGFloat(slider.value))
        // 为了节约性能，把pan手势更新label的代码放在这里更新
        forwardLabel.text = "\(currentDuration.text!) / \(totalDuration.text!) "
    }
    
    @objc fileprivate func sliderDidChanged(slider : UISlider) {
        let second = duration * CGFloat(slider.value)
        seekToTime(seconds: second)
        isInteraction = false
        addDurationTimer()
        addAutoHideTimer()
    }
}

// MARK: - 手势交互处理 contolBar 隐藏 显示 控制 亮度 声音 控制
extension ZYPlayer {
    @objc fileprivate func playerViewDidTap() {
        controlBar.alpha == 1.0 ? hideControlBar() : showControlBar()
    }
    
    @objc fileprivate func playerViewDidPan(pan : UIPanGestureRecognizer) {
        // 竖屏方向不响应
        if !UIDevice.current.orientation.isLandscape { return }
        let localPoint = pan.location(in: playerView)
        let velocityPoint = pan.velocity(in: playerView)        // 得到速率点
        let transitionPoint = pan.translation(in: playerView)
        switch pan.state {
        case .began:
            // 使用绝对值得出pan是水平还是垂直方向
            let x = fabsf(Float(velocityPoint.x))
            let y = fabsf(Float(velocityPoint.y))
            if x > y {  // 水平方向
                // 如果是停止状态 不能快进快退
                if state != .stopped {
                    // 当前播放器播放的位置(秒)
                    let time = player!.currentTime()
                    sumTime = Float(time.value) / Float(time.timescale)
                }
                isHorizontalMove = true
            } else {    // 垂直方向
                isHorizontalMove = false
            }
        case .changed:
            if isHorizontalMove {
                if state != .stopped {
                    // slider 每次叠加的时间
                    sumTime += Float(velocityPoint.x) / Float(200)
                    forwardView.isHidden = false
                    if sumTime > Float(duration) {
                        sumTime = Float(duration)
                    } else if sumTime < 0 {
                        sumTime = 0
                    }
                    slider.value = sumTime / Float(duration)
                    sliderIsSlipping(slider: slider)
                    if transitionPoint.x < 0 {          // 往左滑动
                        forwardImageView.image = UIImage(named: "ZYPlayer_goback")
                    } else {
                        forwardImageView.image = UIImage(named: "ZYPlayer_forward")
                    }
                }
            } else {        // 垂直方向pan手势
                if localPoint.x < UIScreen.main.bounds.height * 0.5 {
                    UIScreen.main.brightness -= velocityPoint.y / CGFloat(10000)
                } else {
                    getSystemVolumnSlider()?.value -= Float(velocityPoint.y) / Float(10000)
                }
            }
        case .ended:
            if isHorizontalMove {
                sumTime = 0
                sliderDidChanged(slider: slider)
            }
            forwardView.isHidden = true
            break
        default:
            break
        }
    }
    
    fileprivate func hideControlBar() {
        UIView.animate(withDuration: 0.5, animations: {
            self.controlBar.alpha = 0.01
        }) { (_) in
            self.controlBar.isHidden = true
        }
    }
    
    fileprivate func showControlBar() {
        self.controlBar.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.controlBar.alpha = 1.0
        }
    }

}

// MARK: - Timer 添加 和 处理
extension ZYPlayer {
    
    /** 定时更新播放进度 */
    @objc fileprivate func handleDurationTimer(){
        let cur = CGFloat((playerItem?.currentTime().value)!) / CGFloat((playerItem?.currentTime().timescale)!)
        currentDuration.text = timeFormate(time: cur)
        slider.value = Float(cur / duration)
    }
    
    /** 自动 隐藏交互条 */
    @objc fileprivate func handleAutoTimer() {
        if isInteraction { return }     // 正在交互
        if controlBar.alpha == 1.0 {
            hideControlBar()
        }
    }
    
    fileprivate func addDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        durationTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.handleDurationTimer), userInfo: nil, repeats: true)
    }
    
    fileprivate func addAutoHideTimer() {
        autoTimer?.invalidate()
        autoTimer = nil
        autoTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.handleAutoTimer), userInfo: nil, repeats: true)
    }
}

// MARK: - 通知 && KVO 监听
extension ZYPlayer {
    /** 添加通知 */
    fileprivate func addNotificationObserver() {
        // 监听屏幕旋转的通知
        NotificationCenter.default.addObserver(self, selector: #selector(self.screenDidRotate(note:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        // 监听app 进入后台 返回前台的通知
        NotificationCenter.default.addObserver(self, selector: #selector(self.appDidEnterBackground), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appDidEnterPlayGround), name: NSNotification.Name.UIApplicationDidBecomeActive, object: self)
        // 监听 playerItem 的状态通知
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidPlayToEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemPlaybackStalled), name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: playerItem)
    }
    
    /** KVO */
    fileprivate func addKVOObserver() {
        playerItem?.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        playerItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: NSKeyValueObservingOptions.new, context: nil)
        playerItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: NSKeyValueObservingOptions.new, context: nil)
        playerItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: NSKeyValueObservingOptions.new, context: nil)
    }
}

// MARK: - KVO 监听处理
extension ZYPlayer {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let playerItem = object as! AVPlayerItem
        if keyPath == "status" {
            if playerItem.status == AVPlayerItemStatus.readyToPlay {
                monitoringPlayback()    // 准备播放
            } else {                    // 初始化播放器失败了
                state = .stopped
            }
        } else if keyPath == "loadedTimeRanges" {                                           //监听播放器的下载进度
            calculateBufferedProgress(playerItem)
        } else if keyPath == "playbackBufferEmpty" && playerItem.isPlaybackBufferEmpty {    //监听播放器在缓冲数据的状态
            state = .buffering
            indicator.startAnimating()
            indicator.isHidden = false
            pauseToPlay()
        } else if keyPath == "playbackLikelyToKeepUp" {     // 缓存足够了，可以播放
            indicator.stopAnimating()
            indicator.isHidden = true
        }
    }
    
    fileprivate func monitoringPlayback() {
        duration = CGFloat(playerItem!.duration.value) / CGFloat(playerItem!.duration.timescale) // 视频总时间
        totalDuration.text = timeFormate(time: duration)
        startToPlay()
    }
    
    fileprivate func calculateBufferedProgress(_ palyerItem : AVPlayerItem) {
        let bufferedRanges = playerItem?.loadedTimeRanges
        let timeRange = bufferedRanges?.first?.timeRangeValue   // 获取缓冲区域
        let startSeconds = CMTimeGetSeconds(timeRange!.start)
        let durationSeconds = CMTimeGetSeconds(timeRange!.duration)
        let timeInterval = startSeconds + durationSeconds
        let duration = playerItem!.duration
        let totalDuration = CMTimeGetSeconds(duration)
        bufferedProgress = Float(timeInterval)/Float(totalDuration)
        progressView.progress = bufferedProgress
    }
}

// MARK: - 通知处理
extension ZYPlayer {
    
    /** 进入后台通知 */
    @objc fileprivate func appDidEnterBackground() {
        state = .stopped
        pauseToPlay()
    }
    
    /** 返回前台通知 */
    @objc fileprivate func appDidEnterPlayGround() {
        if state == .pause {
            state = .playing
            startToPlay()
        }
    }
    
    /** 播放完毕通知 */
    @objc fileprivate func playerItemDidPlayToEnd() {
        state = .stopped
        releasePlayer()
        centerBtn.isHidden = false
    }
    
    /** 播放异常中断通知 */
    @objc fileprivate func playerItemPlaybackStalled() {
        state = .stopped
        releasePlayer()
        centerBtn.isHidden = false
    }
    
    /** 屏幕旋转通知 */
    @objc fileprivate func screenDidRotate(note : Notification) {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            rotateToPortrait()
            break
        case .portraitUpsideDown:
            break
        case .landscapeLeft:
            rotateToLandscapeLeft()
        case .landscapeRight:
            rotateToLandscapeRight()
        default:
            break
        }
    }
}

// MARK: - 播放 暂停 定位播放 处理
extension ZYPlayer {
    /** 开始播放 */
    fileprivate func startToPlay() {
        if player == nil {
            indicator.startAnimating()
            indicator.isHidden = false
            initPlayer(url!)
        }
        addDurationTimer()
        addAutoHideTimer()
        playPauseBtn.isSelected = true
        state = .playing
        player?.play()
    }

    /** 暂停播放 */
    fileprivate func pauseToPlay() {
        durationTimer?.invalidate()
        autoTimer?.invalidate()
        indicator.stopAnimating()
        indicator.isHidden = true
        state = .stopped
        playPauseBtn.isSelected = false
        player?.pause()
    }
    
    /** 匹配播放的位置 */
    fileprivate func seekToTime(seconds : CGFloat) {
        guard state != .stopped else { return }
        var second = max(0, seconds)
        second = min(seconds, duration)
        pauseToPlay()
        player?.seek(to: CMTimeMakeWithSeconds(Float64(second), Int32(NSEC_PER_SEC)) , completionHandler: { [weak self](_) in
            self?.startToPlay()
            if !self!.playerItem!.isPlaybackLikelyToKeepUp {
                self?.state = .buffering
            }
        })
    }
}

// MARK: - 屏幕旋转处理
extension ZYPlayer {
    fileprivate func rotateToLandscapeLeft() {
        if lastOrientation == .landscapeLeft { return }
        keyWindow.addSubview(self.view)
        // UIView动画进行旋转
        UIView.animate(withDuration: 0.4, animations: {
            self.view.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
            self.view.frame = self.keyWindow.bounds
            self.playerLayer?.frame = self.view.bounds
        })
        fullBtn.isSelected = true
        lastOrientation = .landscapeLeft
        UIApplication.shared.isStatusBarHidden = true
    }
    
    fileprivate func rotateToLandscapeRight() {
        if lastOrientation == .landscapeRight { return }
        keyWindow.addSubview(self.view)
        UIView.animate(withDuration: 0.4) {
            self.view.transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
            self.view.frame = self.keyWindow.bounds
            self.playerLayer?.frame = self.view.bounds
        }
        fullBtn.isSelected = true
        lastOrientation = .landscapeRight
        UIApplication.shared.isStatusBarHidden = true
    }
    
    fileprivate func rotateToPortrait() {
        if lastOrientation == .portrait { return }
        orgView?.addSubview(self.view)
        UIView.animate(withDuration: 0.4) {
            self.view.transform = CGAffineTransform(rotationAngle: 0)
            self.view.frame = self.orgFrame!
            self.playerLayer?.frame = self.view.bounds
        }
        fullBtn.isSelected = false
        lastOrientation = .portrait
        UIApplication.shared.isStatusBarHidden = false 
    }
}

// MARK: - 销毁播放器
extension ZYPlayer {
    open func releasePlayer() {
        guard playerItem != nil else { return }
        NotificationCenter.default.removeObserver(self)
        playerItem?.removeObserver(self, forKeyPath: "status")
        playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        playerItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        playerItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        player?.replaceCurrentItem(with: nil)
        playerItem = nil
        durationTimer?.invalidate()
        durationTimer = nil
        autoTimer?.invalidate()
        autoTimer = nil
        // UI 恢复到初始的状态
        playPauseBtn.isSelected = false
    }
}

// MARK: - 时间显示 格式转换
extension ZYPlayer {
    fileprivate func timeFormate(time : CGFloat) -> String {
        let t = Int(time)
        var timeStr = ""
        if t < 3600 {
            timeStr = String(format: "%02d:%02d", t / 60, t % 60)
        } else {
            timeStr = String(format: "%02d:%02d:02d", t / 3600, t / 3600 / 60, (t / 3600 / 60) % 60)
        }
        return timeStr
    }
}
