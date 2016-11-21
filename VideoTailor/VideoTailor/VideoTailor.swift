//
//  VideoTailor.swift
//  VideoTailor
//
//  Created by Worthy on 16/11/16.
//  Copyright © 2016年 Worthy Zhang. All rights reserved.
//

import UIKit
import AVFoundation

public protocol VideoTailorDelegate: class {
    func exportFailed(error: Error?)
    func exportSuccess(outputUrl: URL)
    func exportProgress(progress: CGFloat)
}

public class VideoTailor: NSObject {
    
    // public
    public weak var delegate: VideoTailorDelegate?
    public var exportFailedHandler: ((_ error: Error?)->Void)?
    public var exportSuccessHandler: ((_ outputUrl: URL)->Void)?
    public var exportProgressHandler: ((_ progress: CGFloat)->Void)?
    
    public var outputSize: CGSize?
    public var rect: CGRect?
    public var timeRange: CMTimeRange?
    public var bitRate: Int64?
    public var profile: String?
    public var fileType: String?
    public var outputUrl: URL?
    
    // private
    var writer: AVAssetWriter?
    var writerVideoInput: AVAssetWriterInput?
    var writerAudioInput: AVAssetWriterInput?
    var reader: AVAssetReader?
    var readerVideoOutput: AVAssetReaderVideoCompositionOutput?
    var readerAudioOutput: AVAssetReaderAudioMixOutput?
    var videoExportQueue: DispatchQueue?
    var audioExportQueue: DispatchQueue?
    
    var videoExportFinished = false
    var audioExprotFinished = false
    
    var audioTrackExists = false
    
    // MARK: public
    
    public func export(_ asset: AVAsset, _ rect: CGRect, _ timeRange: CMTimeRange, _ outputSize: CGSize, _ outputUrl: URL) {
        self.rect = rect
        self.outputSize = outputSize
        self.timeRange = timeRange
        export(asset,outputUrl)
    }
    
    public func export(_ asset: AVAsset, _ rect: CGRect, _ outputSize: CGSize, _ outputUrl: URL) {
        self.rect = rect
        self.outputSize = outputSize
        export(asset,outputUrl)
    }
    
    public func export(_ asset: AVAsset, _ timeRange: CMTimeRange, _ outputUrl: URL) {
        self.timeRange = timeRange
        export(asset,outputUrl)
    }
    
    
    public func cancel() {
        writer?.cancelWriting()
        reader?.cancelReading()
        failedHandler(error: nil)
    }
    
    func export(_ asset: AVAsset, _ outputUrl: URL) {
        self.outputUrl = outputUrl
        setupExportSession(asset, outputUrl)
        startExportSession()
    }
    
    // MARK: export session
    
    func setupExportSession(_ asset: AVAsset,_ outputUrl: URL) {
        
        // composition
        let composition = createComposition(asset: asset)
        
        // reader
        do {
            reader = try AVAssetReader(asset: composition)
        } catch {
            failedHandler(error: nil)
            return
        }
        readerVideoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: composition.tracks(withMediaType: AVMediaTypeVideo), videoSettings: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
        readerVideoOutput?.alwaysCopiesSampleData = false
        readerVideoOutput?.videoComposition = createVideoComposition(composition: composition)
        reader?.add(readerVideoOutput!)

        // writer
        do {
            writer = try AVAssetWriter(outputURL: outputUrl, fileType: fileType ?? AVFileTypeMPEG4)
        } catch {
            failedHandler(error: nil)
            return
        }
        writerVideoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings())
        writer?.add(writerVideoInput!)

        // queue
        videoExportQueue = DispatchQueue(label: "com.worthy.tailor.video")
        
        // audio
        if audioTrackExists {
            readerAudioOutput = AVAssetReaderAudioMixOutput(audioTracks: composition.tracks(withMediaType: AVMediaTypeAudio), audioSettings: [AVFormatIDKey:kAudioFormatLinearPCM])
            readerAudioOutput?.alwaysCopiesSampleData = false
            reader?.add(readerAudioOutput!)
            writerAudioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings())
            writer?.add(writerAudioInput!)
            audioExportQueue = DispatchQueue(label: "com.worthy.tailor.audio")
        }else {
            audioExprotFinished = true
        }
    }
    
    func startExportSession() {
        reader?.startReading()
        writer?.startWriting()
        writer?.startSession(atSourceTime: kCMTimeZero)
        // video
        writerVideoInput?.requestMediaDataWhenReady(on: videoExportQueue!, using: {
            while self.writerVideoInput!.isReadyForMoreMediaData {
                if let sampleBuffer = self.readerVideoOutput?.copyNextSampleBuffer() {
                    self.writerVideoInput?.append(sampleBuffer)
                    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let progress = CMTimeGetSeconds(time)/CMTimeGetSeconds(self.timeRange!.duration)
                    self.progressHandler(progress: CGFloat(progress))
                }else {
                    if !self.videoExportFinished {
                        self.videoExportFinished = true
                        self.writerVideoInput?.markAsFinished()
                        self.checkExportSession()
                        break;
                    }
                }
                
            }
        })
        
        // audio
        if audioTrackExists {
            writerAudioInput?.requestMediaDataWhenReady(on: audioExportQueue!, using: {
                while self.writerAudioInput!.isReadyForMoreMediaData {
                    if let sampleBuffer = self.readerAudioOutput?.copyNextSampleBuffer() {
                        self.writerAudioInput?.append(sampleBuffer)
                    }else {
                        if !self.audioExprotFinished {
                            self.audioExprotFinished = true
                            self.writerAudioInput?.markAsFinished()
                            self.checkExportSession()
                            break;
                        }
                    }
                    
                }
            })
        }
    }
    
    func checkExportSession() {
        if audioExprotFinished && videoExportFinished {
            writer?.finishWriting {
                if let error = self.writer?.error {
                    self.failedHandler(error: error)
                }else {
                    self.successHandler()
                }
            }
        }
    }
    
    func createComposition(asset: AVAsset) -> AVMutableComposition {
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let sourceVideoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first
        let sourceAudioTrack = asset.tracks(withMediaType: AVMediaTypeAudio).first
        
        // set optional values
        if bitRate == nil {
            bitRate = Int64(sourceAudioTrack!.estimatedDataRate + sourceVideoTrack!.estimatedDataRate)
        }
        if timeRange == nil {
            timeRange = sourceVideoTrack?.timeRange
        }
        if outputSize == nil {
            outputSize = transformedSize(sourceVideoTrack!)
        }
        if rect == nil {
            rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        // add tracks
        if let track = sourceVideoTrack {
            do {
                try compositionVideoTrack.insertTimeRange(timeRange!, of: track, at: kCMTimeZero)
                compositionVideoTrack.preferredTransform = track.preferredTransform
            } catch {
            }
        }
        if let track = sourceAudioTrack {
            do {
                try compositionAudioTrack.insertTimeRange(timeRange!, of: track, at: kCMTimeZero)
            } catch {
                audioTrackExists = false
            }
            audioTrackExists = true
        }else {
            audioTrackExists = false
        }
        return composition
    }
    
    func createVideoComposition(composition: AVMutableComposition) -> AVMutableVideoComposition {
        let videoTrack = composition.tracks(withMediaType: AVMediaTypeVideo).first!
        // transform
        var offsetX, offsetY, rotate: CGFloat
        
        var sourceSize = transformedSize(videoTrack)
        let trackTrans = videoTrack.preferredTransform
        let middleSize = CGSize(width: sourceSize.width * rect!.width, height: sourceSize.height*rect!.height)
        let scale = outputSize!.width / middleSize.width
        
        if trackTrans.b == 1 && trackTrans.c == -1 {            //90 angle
            rotate = CGFloat(M_PI_2)
            offsetX = (1 - rect!.origin.x) * sourceSize.width;
            offsetY = -rect!.origin.y * sourceSize.height;
        }else if (trackTrans.a == -1 && trackTrans.d == -1) {   //180 angle
            rotate = CGFloat(M_PI)
            offsetX = (1 - rect!.origin.x) * sourceSize.width;
            offsetY = (1 - rect!.origin.y) * sourceSize.height;
        }else if (trackTrans.b == -1 && trackTrans.c == 1) {    //270 angle
            rotate = CGFloat(M_PI_2 * 3)
            offsetX = -rect!.origin.x * sourceSize.width
            offsetY = (1-rect!.origin.y) * sourceSize.height
        }else{
            rotate = 0;
            offsetX = -rect!.origin.x * sourceSize.width
            offsetY = -rect!.origin.y * sourceSize.height
        }
        var transform = CGAffineTransform(rotationAngle: rotate)
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: offsetX*scale, y: offsetY*scale))
        
        // instruction
        let instruction = AVMutableVideoCompositionInstruction()
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.timeRange = videoTrack.timeRange
        instruction.layerInstructions = [layerInstruction]
        layerInstruction.setTransform(transform, at: kCMTimeZero)
        
        // videoComposition
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition)
        videoComposition.renderSize = outputSize!
        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTimeMake(1, Int32(videoTrack.nominalFrameRate))
        
        return videoComposition
    }
    
    func transformedSize(_ videoTrack: AVAssetTrack) -> CGSize{
        let naturalSize = videoTrack.naturalSize
        var sourceSize = naturalSize
        let trackTrans = videoTrack.preferredTransform
        if (trackTrans.b == 1 && trackTrans.c == -1)||(trackTrans.b == -1 && trackTrans.c == 1) {
            sourceSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        }
        return sourceSize
    }
    
    // MARK: handler
    
    func failedHandler(error: Error?) {
        DispatchQueue.main.async {
            self.delegate?.exportFailed(error: error)
            self.exportFailedHandler?(error)
        }
    }
    
    func successHandler() {
        DispatchQueue.main.async {
            self.delegate?.exportProgress(progress: 1.0)
            self.delegate?.exportSuccess(outputUrl: self.outputUrl!)
            self.exportProgressHandler?(1.0)
            self.exportSuccessHandler?(self.outputUrl!)
        }
    }
    
    func progressHandler(progress: CGFloat) {
        DispatchQueue.main.async {
            self.delegate?.exportProgress(progress: progress)
            self.exportProgressHandler?(progress)
        }
    }
    
    // MARK: configuration
    
    func videoOutputSettings() -> [String: Any] {
        let width = outputSize!.width
        let height = outputSize!.height
        return [AVVideoHeightKey: height,
                AVVideoWidthKey: width,
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoScalingModeKey:AVVideoScalingModeResizeAspectFill,
                AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:bitRate!,
                                                 AVVideoProfileLevelKey:profile ?? AVVideoProfileLevelH264MainAutoLevel,
                                                 AVVideoCleanApertureKey:[
                                                    AVVideoCleanApertureWidthKey:width,
                                                    AVVideoCleanApertureHeightKey:height,
                                                    AVVideoCleanApertureHorizontalOffsetKey:10,
                                                    AVVideoCleanApertureVerticalOffsetKey:10],
                                                AVVideoPixelAspectRatioKey:[
                                                    AVVideoPixelAspectRatioHorizontalSpacingKey:1,
                                                    AVVideoPixelAspectRatioVerticalSpacingKey:1]
            ]
        ]
    }
    
    func audioOutputSettings() -> [String: Any] {
        var audioChannelLayout = AudioChannelLayout()
        memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size);
        audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono

        let audioChannelLayoutValue = NSData(bytes: &audioChannelLayout,
               length: MemoryLayout<AudioChannelLayout>.size)
        
        let sampleRate = AVAudioSession.sharedInstance().sampleRate
        return [AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey:sampleRate,
                AVChannelLayoutKey:audioChannelLayoutValue,
                AVNumberOfChannelsKey: 1
        ]
    }
}
