//
//  CutViewController.swift
//  VideoTailorDemo
//
//  Created by Worthy on 16/11/17.
//  Copyright © 2016年 Worthy Zhang. All rights reserved.
//

import UIKit
import AVFoundation
import VideoTailor

class CutViewController: UIViewController {

    @IBOutlet weak var cropView: VideoCropView!
    @IBOutlet weak var labelProgress: UILabel!
    
    var outputSize = CGSize(width: 200, height: 200)
    
    var asset: AVAsset!
    var tailor: VideoTailor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cropView.load(asset: asset, cropSize: outputSize)
        cropView.play()
    }
    
    
    
    @IBAction func didTapExportButton(_ sender: Any) {
        let root = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        let path = root!+"/out.mp4"
        if FileManager.default.fileExists(atPath: path) {
            try! FileManager.default.removeItem(atPath: path)
        }
        
        let rect = cropView.cropRect()
        tailor = VideoTailor()
        tailor?.delegate = self
        tailor?.export(asset, rect, outputSize, URL(fileURLWithPath: path))
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    static func storyboardInstance() -> CutViewController {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier:  String(describing: CutViewController.self))
        return vc as! CutViewController
    }
    
}

extension CutViewController: VideoTailorDelegate {
    
    func exportProgress(progress: CGFloat) {
        labelProgress.text = "\(progress)"
    }
    
    func exportFailed(error: Error?) {
        labelProgress.text = "falied"
    }
    
    func exportSuccess(outputUrl: URL) {
        labelProgress.text = "success"
        UISaveVideoAtPathToSavedPhotosAlbum(outputUrl.path, nil, nil, nil)
        self.navigationController?.popViewController(animated: true)
    }
    
    
}

