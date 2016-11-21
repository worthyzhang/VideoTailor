//
//  ViewController.swift
//  VideoTailorDemo
//
//  Created by Worthy on 16/11/16.
//  Copyright © 2016年 Worthy Zhang. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

class ViewController: UIViewController {

    @IBOutlet weak var textFieldWidth: UITextField!
    @IBOutlet weak var textFieldHeight: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func didTapPickButton(_ sender: Any) {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        pickerVC.modalPresentationStyle = .currentContext
        pickerVC.videoQuality = .typeLow
        pickerVC.mediaTypes = [kUTTypeMovie as String]
        self.navigationController?.present(pickerVC, animated: true, completion: nil)
    }

}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.navigationController?.dismiss(animated: true, completion: nil)
        
        let url = info[UIImagePickerControllerReferenceURL] as! URL
        let width = Int.init(textFieldWidth.text!)
        let height = Int.init(textFieldHeight.text!)
        
        let vc = CutViewController.storyboardInstance()
        vc.asset = AVURLAsset(url: url)
        vc.outputSize = CGSize(width: width!, height: height!)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

