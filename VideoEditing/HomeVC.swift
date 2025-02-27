//
//  HomeVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import UIKit

@available(iOS 16.0, *)
class HomeVC: UIViewController {
    
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var musicButton: UIButton!
    @IBOutlet weak var stickerButton: UIButton!
    @IBOutlet weak var speedButton: UIButton!
    @IBOutlet weak var filterButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cropButton.layer.cornerRadius = 10
        self.textButton.layer.cornerRadius = 10
        self.musicButton.layer.cornerRadius = 10
        self.stickerButton.layer.cornerRadius = 10
        self.speedButton.layer.cornerRadius = 10
        self.filterButton.layer.cornerRadius = 10
    }
    
    @IBAction func cropButton(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "VideoCroppingVC") as! VideoCroppingVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func textButton(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "VideoTextVC") as! VideoTextVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func musicButton(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "VideoEditingVC") as! VideoEditingVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func speedButton(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "VideoSpeedVC") as! VideoSpeedVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func stickerButton(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "VideoStickerVC") as! VideoStickerVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func filterButton(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "VideoFilterVC") as! VideoFilterVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
