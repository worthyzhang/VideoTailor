//
//  VideoCropView.swift
//  VideoTailorDemo
//
//  Created by Worthy on 16/11/17.
//  Copyright © 2016年 Worthy Zhang. All rights reserved.
//

import UIKit
import AVFoundation


class VideoCropView: UIView {
    let scrollView = UIScrollView()
    var playerLayer: AVPlayerLayer?
    var player: AVPlayer?
    
    
    
    var videoSize = CGSize.zero
    var cropSize = CGSize.zero
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        adjustLayout()
    }
    
    func setupUI() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
    }
    
    func adjustLayout() {
        if videoSize.equalTo(CGSize.zero) || cropSize.equalTo(CGSize.zero) {
            return
        }
        let length = bounds.width
        let videoRatio = videoSize.width/videoSize.height
        let cropRatio = cropSize.width/cropSize.height
        
        // calculate scrollSize
        var scrollSize = CGSize.zero
        var scrollOrigin = CGPoint.zero
        if cropRatio > 1 {
            scrollSize = CGSize(width: length, height: length/cropRatio)
            scrollOrigin = CGPoint(x: CGFloat(0), y: (1-1/cropRatio)*0.5*length)
        }else {
            scrollSize = CGSize(width: length*cropRatio, height: length)
            scrollOrigin = CGPoint(x: (1-cropRatio)*0.5*length, y: CGFloat(0))
        }
        // calculate contentSize
        var contentSize = CGSize.zero
        if videoRatio > cropRatio {
            contentSize = CGSize(width: scrollSize.height*videoRatio, height: scrollSize.height)
        }else {
            contentSize = CGSize(width: scrollSize.width, height: scrollSize.width/videoRatio)
        }
        scrollView.frame = CGRect(origin: scrollOrigin, size: scrollSize)
        scrollView.contentSize = contentSize
        //scrollView.center = CGPoint(x: bounds.width/2, y: bounds.height/2)
        playerLayer?.frame = CGRect(origin: CGPoint.zero, size: contentSize)
    }
    
    // MARK: Public
    
    func load(asset: AVAsset, cropSize: CGSize) {
        videoSize = transformedSize(asset)
        self.cropSize = cropSize
        
        player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playerLayer = AVPlayerLayer(player: player)
        scrollView.layer.addSublayer(playerLayer!)
        adjustLayout()
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func cropRect() -> CGRect {
        let contentOffset = scrollView.contentOffset
        let contentSize = scrollView.contentSize
        let scrollViewSize = scrollView.frame.size
        
        let origin = CGPoint(x: contentOffset.x/contentSize.width, y: contentOffset.y/contentSize.height)
        let size = CGSize(width: scrollViewSize.width/contentSize.width, height: scrollViewSize.height/contentSize.height)
        
        return CGRect(origin: origin, size: size)
    }
    
    
    func transformedSize(_ asset: AVAsset) -> CGSize {
        let videoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first
        if let track = videoTrack {
            let naturalSize = track.naturalSize
            var sourceSize = naturalSize
            let trackTrans = track.preferredTransform
            if (trackTrans.b == 1 && trackTrans.c == -1)||(trackTrans.b == -1 && trackTrans.c == 1) {
                sourceSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            }
            return sourceSize
        }
        return CGSize(width: 0, height: 0)
    }
    
    
}
