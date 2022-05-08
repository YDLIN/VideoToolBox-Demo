//
//  VideoCaptureConfig.swift
//  EncodeH264
//
//  Created by Du on 2022/5/6.
//

import Foundation
import AVFoundation

struct MirrorType: OptionSet {
    let rawValue: Int
    static let none = MirrorType(rawValue: 1)
    static let front = MirrorType(rawValue: 2)
    static let back = MirrorType(rawValue: 4)
    static let all = MirrorType(rawValue: 3)
}

struct VideoCaptureConfig {
    /// 视频采集参数，比如分辨率等，与画质相关
    var preset = AVCaptureSession.Preset.hd1280x720
    /// 摄像头位置 - 前置/后置摄像头
    var position = AVCaptureDevice.Position.back
    /// 视频画面方向
    var orientation = AVCaptureVideoOrientation.portrait
    /// 帧率
    var fps = 30
    
    /*
     颜色空间格式
     1、一般我们采集图像用于后续的编码时，这里设置 kCVPixelFormatType_420YpCbCr8BiPlanarFullRange 即可。
     2、如果想支持 HDR 时（iPhone 12 及之后设备才支持），这里设置为：kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange。
     */
    var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    /// 镜像类型
    var mirrorType = MirrorType.front
}
