//
//  VideoCapture.swift
//  EncodeH264
//
//  Created by Du on 2022/5/6.
//

import UIKit
import AVFoundation


enum VideCaptureError: Error {
    case sessionRuntimeError
    case unKnowed
}

class VideoCapture: NSObject {
    /// 对外可见
    public var config: VideoCaptureConfig {
        get {
            return privateConfig
        }
    }
    
    private var privateConfig = VideoCaptureConfig()
    
    /// 后置摄像头采集输入
    lazy private var backDeviceInput = setupBackDeviceInput()
    
    /// 前置摄像头采集输入
    lazy private var frontDeviceInput = setupFrontDeviceInput()
    
    /// 视频采集输出
    lazy private var videoOutput = setupVideoOutput()
    
    /// 视频采集会话
    lazy private var captureSession = setupCaptureSession()
    
    /// 视频采集分辨率
    lazy private var sessionPresetSize = setupSessionPresetSize()
    /// 捕获队列
    private var captureQueue: DispatchQueue?
    
    /// 视频预览渲染 layer
    lazy public var previewLayer = setupPreviewLayer()
    
    /// 视频采集设备
    lazy private var captureDevice = setupCaptureDevice()
    
    /// 视频采集回话初始化成功回调
    var sessionInitSuccessClosure: (() -> ())?
    /// 视频采集会话错误回调
    var sessionErrorClosure: ((VideCaptureError) -> ())?
    /// 视频采集数据回调
    var sampleBufferOutputClosure: ((CMSampleBuffer) -> ())?
    
    
    init(config: VideoCaptureConfig) {
        super.init()
        self.privateConfig = config
        captureQueue = DispatchQueue(label: "com.VideoToolBox.VideoCapture")
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 开始采集
    func startRunning() {
        captureQueue?.async { [weak self] in
            if let strongSelf = self {
                strongSelf.start()
            }
        }
    }
    
    /// 停止采集
    func stopRunning() {
        captureQueue?.async { [weak self] in
            if let strongSelf = self {
                strongSelf.stop()
            }
        }
    }
    
    /// 切换摄像头
    /// - Parameter position: 前/后置摄像头
    func changedDevice(position: AVCaptureDevice.Position) {
        captureQueue?.async { [weak self] in
            if let strongSelf = self {
                strongSelf.updatedDevice(position: position)
            }
        }
    }
}

extension VideoCapture {
    private func backCamera() -> AVCaptureDevice? {
        return camera(position: .back)
    }
    
    private func frontCamera() -> AVCaptureDevice? {
        return camera(position: .front)
    }
    
    // MARK:- Utility
    /// 获取符合要求的采集设备
    /// - Parameter position: 前/后置摄像头
    /// - Returns: 采集设备
    private func camera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position)

            return deviceDiscoverySession.devices.filter { $0.position == position }.first
        } else {
            return AVCaptureDevice.devices(for: .video).filter {
                $0.position == position
            }.first
        }
    }
    
    // MARK:- Notification
    @objc
    private func sessionRuntimeError(_ notify: Notification) {
        if let closure = sessionErrorClosure, let userInfo = notify.userInfo {
            let _ = userInfo[AVCaptureSessionErrorKey]
            closure(VideCaptureError.sessionRuntimeError)
        }
    }
    
    /// 获取预设列表
    private func sessionPresetList() -> Array<AVCaptureSession.Preset> {
        return [config.preset, AVCaptureSession.Preset.hd4K3840x2160, AVCaptureSession.Preset.hd1920x1080, AVCaptureSession.Preset.hd1280x720, AVCaptureSession.Preset.low]
    }
    
    /// 更新画面方向
    private func updateOrientation() {
        /// 用来把输入输出连接起来
        guard let connection = videoOutput.connection(with: .video) else {
            return
        }
        
        if connection.isVideoOrientationSupported && connection.videoOrientation != config.orientation {
            connection.videoOrientation = config.orientation
        }
    }
    
    /// 更新画面镜像
    private func updateMirror() {
        /// 用来把输入输出连接起来
        guard let connection = videoOutput.connection(with: .video) else {
            return
        }
        
        if connection.isVideoOrientationSupported {
            if config.mirrorType.contains(MirrorType.front) && config.position == .front {
                connection.isVideoMirrored = true
            } else if config.mirrorType.contains(MirrorType.back) && config.position == .back {
                connection.isVideoMirrored = true
            } else {
                connection.isVideoMirrored = false
            }
        }
    }
    
    /// 更新采集实时帧率
    @discardableResult
    private func updateActiveFrameDuration() -> Bool {
        /// 1、帧率换算成帧间隔时长
        let frameDuration = CMTimeMake(value: 1, timescale: Int32(config.fps))
        
        /// 2、设置帧率大于 30 时，找到满足该帧率及其他参数，并且当前设备支持的 AVCaptureDeviceFormat
        if config.fps > 30 {
            guard let presetSize = sessionPresetSize else {
                return false
            }
            captureDevice?.formats.forEach { vformat in
                let dessciption = vformat.formatDescription
                let dims = CMVideoFormatDescriptionGetDimensions(dessciption)
                let maxRate = Int(vformat.videoSupportedFrameRateRanges[0].maxFrameRate)
                if maxRate >= config.fps && CMFormatDescriptionGetMediaSubType(dessciption) == config.pixelFormatType && (presetSize.width * presetSize.height == dims.width * dims.height) {
                    captureDevice?.activeFormat = vformat
                }
            }
        }
        
        /// 3、检查设置的帧率是否在当前设备的 activeFormat 支持的最低和最高帧率之间。如果是，就设置帧率
        var support = false
        if let device = captureDevice {
            for (_, item) in device.activeFormat.videoSupportedFrameRateRanges.enumerated() {
                if CMTimeCompare(frameDuration, item.minFrameDuration) >= 0 && CMTimeCompare(frameDuration, item.maxFrameDuration) <= 0 {
                    support = true
                }
            }
        }
        
        if support {
            captureDevice?.activeVideoMinFrameDuration = frameDuration
            captureDevice?.activeVideoMaxFrameDuration = frameDuration
            return support
        }
        return false
    }
    
    
    
    private func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            guard let cpSession = captureSession else {
                print("captureSession is empty.")
                return
            }
            if !cpSession.isRunning {
                cpSession.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    print("the user has granted to access the camera.")
                    guard let cpSession = self.captureSession else {
                        print("captureSession is empty.")
                        return
                    }
                    if !cpSession.isRunning {
                        cpSession.startRunning()
                    }
                } else {
                    print("the user has not granted to access the camera.")
                }
            }
        case .denied:
            print("the user has denied previously to access the camera.")
        case .restricted:
            print("the user can't give camera access due to some restriction.")
        default:
            print("something has wrong due to we can't access the camera.")
        }
    }
    
    private func stop() {
        guard let cpSession = captureSession else {
            print("captureSession is empty.")
            return
        }
        
        if cpSession.isRunning {
            cpSession.stopRunning()
        }
    }
    
    private func updatedDevice(position: AVCaptureDevice.Position) {
        guard let cpSession = captureSession else {
            print("captureSession is empty.")
            return
        }
        
        if position == config.position || !cpSession.isRunning {
            return
        }
        
        /// 当前输入设备
        let curInput = (config.position == AVCaptureDevice.Position.back) ? backDeviceInput : frontDeviceInput
        /// 准备要切换的输入设备
        let addInput = (config.position == AVCaptureDevice.Position.back) ? frontDeviceInput : backDeviceInput
        guard let curInput = curInput, let addInput = addInput else {
            return
        }
        
        /// 移除当前的输入设备
        cpSession.removeInput(curInput)
        for selectPreset in sessionPresetList() {
            if cpSession.canSetSessionPreset(selectPreset) {
                cpSession.canSetSessionPreset(selectPreset)
                if cpSession.canAddInput(addInput) {
                    cpSession.addInput(addInput)
                    privateConfig.position = position
                    break
                }
            }
        }
        
        updateOrientation()
        updateMirror()
        
        /// 6、更新采集实时帧率
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                updateActiveFrameDuration()
                device.unlockForConfiguration()
            } catch let error {
                print("Failed lockForConfiguration. Error: \(error)")
            }
        }
    }
}

// MARK:- Lazy
extension VideoCapture {
    private func setupCaptureSession() -> AVCaptureSession? {
        let backDevice = backDeviceInput
        let frontDevice = frontDeviceInput
        
        guard let deviceInput = (config.position == .back ? backDevice : frontDevice) else {
            return nil
        }
        
        /// 1、初始化采集会话
        let cpSession = AVCaptureSession()
        
        /// 2、添加采集输入
        sessionPresetList().forEach { selectPreset in
            if cpSession.canSetSessionPreset(selectPreset) {
                cpSession.canSetSessionPreset(selectPreset)
                if cpSession.canAddInput(deviceInput) {
                    cpSession.addInput(deviceInput)
                }
            }
        }
        
        /// 3、添加采集输出
        if cpSession.canAddOutput(videoOutput) {
            cpSession.addOutput(videoOutput)
        }
        
        
        /// 4、更新画面方向
        updateOrientation()
        
        /// 5、更新画面镜像
        updateMirror()
        
        /// 6、更新采集实时帧率
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                updateActiveFrameDuration()
                device.unlockForConfiguration()
            } catch let error {
                print("Failed lockForConfiguration. Error: \(error)")
            }
        }
        
        /// 初始化成功 -> 回调
        if let closure = sessionInitSuccessClosure {
            closure()
        }
        
        return cpSession
    }
    
    private func setupVideoOutput() -> AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()
        /// true 表示：采集的下一帧到来前，如果有还未处理完的帧，丢掉。
        output.alwaysDiscardsLateVideoFrames = true
        /// 设置返回采集数据的代理和回调
        output.setSampleBufferDelegate(self, queue: captureQueue)
        /// 采样像素格式YUV420P
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: config.pixelFormatType]
        return output
    }
    
    private func setupPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let cpSession = captureSession else {
            return nil
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: cpSession)
        layer.videoGravity = .resizeAspectFill
        
        return layer
    }
    
    private func setupSessionPresetSize() -> CMVideoDimensions? {
        if let device = captureDevice {
            return CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        }
        return nil
    }
    
    private func setupBackDeviceInput() -> AVCaptureInput? {
        if let captureDevice = backCamera() {
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                return input
            } catch let error {
                print("Failed to set back input device with error: \(error)")
                return nil
            }
        }
        return nil
    }
    
    private func setupFrontDeviceInput() -> AVCaptureInput? {
        if let captureDevice = frontCamera() {
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                return input
            } catch let error {
                print("Failed to set front input device with error: \(error)")
                return nil
            }
        }
        return nil
    }
    
    private func setupCaptureDevice() -> AVCaptureDevice? {
        return config.position == .back ? backCamera() : frontCamera()
    }
}


// MARK:- Buffer Delegate
extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoOutput {
            if let closure = sampleBufferOutputClosure {
                closure(sampleBuffer)
            }
        }
    }
}
