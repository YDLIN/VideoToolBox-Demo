//
//  VideoCaptureViewController.swift
//  01 - EncodeH264
//
//  Created by Du on 2022/5/6.
//

import UIKit
import CoreMedia
import Photos

class VideoCaptureViewController: UIViewController {
    lazy var videoCaptureConfig = setupConfig()
    lazy var videoCapture = setupVideoCapture()
    var shotCount = 0
    

    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        title = "Video Capture"
        view.backgroundColor = .white
        
        requestAccessForVideo()
        
        let cameraBarBtn = UIBarButtonItem(title: "切换", style: .plain, target: self, action: #selector(changeCamera))
        let shotBarBtn = UIBarButtonItem(title: "截图", style: .plain, target: self, action: #selector(shot))
        
        navigationItem.rightBarButtonItems = [cameraBarBtn, shotBarBtn]
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        videoCapture.previewLayer?.frame = view.bounds
    }
    
    @objc
    private func changeCamera() {
        videoCapture.changedDevice(position: videoCapture.config.position == .back ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back)
    }
    
    @objc
    private func shot() {
        shotCount = 1
    }

}

extension VideoCaptureViewController {
    private func setupConfig() -> VideoCaptureConfig {
        var config = VideoCaptureConfig()
        /// 设置采集处理的颜色空间格式为 32bit BGRA，这样方便将 CMSampleBuffer 转换为 UIImage
        config.pixelFormatType = kCVPixelFormatType_32BGRA
        return config
    }

    private func setupVideoCapture() -> VideoCapture {
        let capture = VideoCapture(config: videoCaptureConfig)
        weak var weakSelf = self
        capture.sessionInitSuccessClosure = {
            print("sessionInitSuccessClosure")
            DispatchQueue.main.async {
                if let strongSelf = weakSelf, let layer = strongSelf.videoCapture.previewLayer {
                    strongSelf.view.layer.addSublayer(layer)
                    strongSelf.videoCapture.previewLayer?.frame = strongSelf.view.bounds
                }
            }
        }

        capture.sampleBufferOutputClosure = { sample in
            if let strongSelf = weakSelf {
                if strongSelf.shotCount > 0 {
                    strongSelf.shotCount -= 1
                    strongSelf.save(sampleBuffer: sample)
                }
            }
        }

        capture.sessionErrorClosure = { error in
            print("VideoCapture Error: \(error.localizedDescription)")
        }
        return capture
    }
}

extension VideoCaptureViewController {
    private func requestAccessForVideo() {
        weak var weakSelf = self
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            if let strongSelf = weakSelf {
                strongSelf.videoCapture.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard let strongSelf = weakSelf else { return }
                
                if granted {
                    strongSelf.videoCapture.startRunning()
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
    
    /// 保存截图
    /// - Parameter sampleBuffer: CMSampleBuffer
    private func save(sampleBuffer: CMSampleBuffer) {
        guard let image = image(from: sampleBuffer) else {
            return
        }

        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized:
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                print("performChanges error: \(String(describing: error?.localizedDescription))")
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                if status == .authorized {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } else {
                    print("something has wrong - notDetermined")
                }
            }
        default:
            print("something has wrong - default")
        }
    }

    /// 从 CMSampleBuffer 中创建 UIImage
    /// - Parameter sampleBuffer: CMSampleBuffer
    /// - Returns: 返回创建好的 UIImage
    private func image(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        /// 从 CMSampleBuffer 获取 CVImageBuffer（也是 CVPixelBuffer）
        let imageBuf = CMSampleBufferGetImageBuffer(sampleBuffer)
        guard let imageBuffer = imageBuf else { return nil }

        /// 锁定 CVPixelBuffer 的基地址
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
//        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
//
//        /// 获取 CVPixelBuffer 每行的字节数
//        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
//        let width = CVPixelBufferGetWidth(imageBuffer)
//        let height = CVPixelBufferGetHeight(imageBuffer)
//
//        /// 创建设备相关的 RGB 颜色空间。这里的颜色空间要与 CMSampleBuffer 图像数据的颜色空间一致
//        let colorSpace = CGColorSpaceCreateDeviceRGB()
//
//        /// 基于 CVPixelBuffer 的数据创建绘制 bitmap 的上下文
////        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

//        guard let context = context else {
//            return nil
//        }

        /// 从 bitmap 绘制的上下文中获取 CGImage 图像
//        let _ = CGContext.makeImage(context)
        let ciimage = CIImage(cvImageBuffer: imageBuffer)
        let ciContent = CIContext(options: nil)
        guard let cgImage = ciContent.createCGImage(ciimage, from: ciimage.extent) else { return nil }

        /// 解锁 CVPixelBuffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags.init(rawValue: 0))

        let image = UIImage(cgImage: cgImage)
        ///  从 CGImage 转换到 UIImage
//        if quartzImage != nil {
//            let image = UIImage(cgImage: quartzImage as! CGImage)
//            return image
//        }

        return image
    }
}
