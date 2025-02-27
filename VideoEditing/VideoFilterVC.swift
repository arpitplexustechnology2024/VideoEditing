//
//  VideoFilterVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import UIKit
import AVFoundation
import Photos

class FilterData {
    static let shared = FilterData()
    var currentFilterInfo: [String: Any]?
    private init() {}
}

class VideoFilterVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    private let filters = ["Original", "Vivid", "Dramatic", "Mono", "Nashville", "Toaster", "1977", "Noir", "Comic", "Crystallize", "Bloom", "Pixellate", "Blur", "Sepia", "Fade", "Sharpen", "HDR", "Vignette", "Tonal", "Dot Matrix", "Edge Work", "X-Ray", "Posterize"]
    
    private var currentFilter: String = "Original"
    private var compositionFilter: CIFilter?
    private var filteredAsset: AVAsset?
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false
    private var playPauseButton: UIButton!
    private var videoLooper: Any?
    private var currentTrimmedAsset: AVAsset?
    private var currentVideoURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayPauseButton()
        setupUI()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoViewTapped))
        videoView.addGestureRecognizer(tapGesture)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoView.bounds
    }
    
    deinit {
        if let videoLooper = videoLooper {
            NotificationCenter.default.removeObserver(videoLooper)
        }
    }
    
    func setupUI() {
        filterButton.layer.cornerRadius = 10
        saveButton.layer.cornerRadius = 10
        
        filterButton.isEnabled = false
        saveButton.isEnabled = false
        
        filterButton.alpha = 0.5
        saveButton.alpha = 0.5
    }
    
    private func setupPlayPauseButton() {
        playPauseButton = UIButton(type: .system)
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        playPauseButton.layer.cornerRadius = 30
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        playPauseButton.isHidden = true
        
        videoView.addSubview(playPauseButton)
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: videoView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 60),
            playPauseButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @IBAction func addVideoButtonTapped(_ sender: UIBarButtonItem) {
        showImageSourceOptions()
    }
    
    @objc func videoViewTapped() {
        togglePlayPause()
    }
    
    @objc func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            playPauseButton.isHidden = false
            
        } else {
            player.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if self.isPlaying {
                    self.playPauseButton.isHidden = true
                }
            }
        }
        
        isPlaying.toggle()
    }
    
    @objc private func replayVideo() {
        player?.seek(to: CMTime.zero)
        player?.play()
        isPlaying = true
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.playPauseButton.isHidden = true
            }
        }
    }
    
    // MARK: - Video Player Methods
    private func setupVideoPlayer(with url: URL) {
        playerLayer?.removeFromSuperlayer()
        
        if let videoLooper = videoLooper {
            NotificationCenter.default.removeObserver(videoLooper)
        }
        
        currentVideoURL = url
        currentTrimmedAsset = AVAsset(url: url)
        
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = videoView.bounds
        
        if let playerLayer = playerLayer {
            videoView.layer.addSublayer(playerLayer)
        }
        videoLooper = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main) { [weak self] _ in
                self?.replayVideo()
            }
        
        videoView.bringSubviewToFront(playPauseButton)
        playPauseButton.isHidden = false
        player?.play()
        isPlaying = true
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.playPauseButton.isHidden = true
            }
        }
    }
    
    // MARK: - Image Picker Methods
    func showImageSourceOptions() {
        let alert = UIAlertController(title: "Select Video", message: "Choose an option", preferredStyle: .actionSheet)
        
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { _ in
            self.requestCameraAccess()
        }
        
        let galleryAction = UIAlertAction(title: "Gallery", style: .default) { _ in
            self.requestGalleryAccess()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(cameraAction)
        alert.addAction(galleryAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            openImagePicker(sourceType: .camera)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.openImagePicker(sourceType: .camera)
                    }
                }
            }
        case .denied, .restricted:
            showSettingsAlert(title: "Camera Access Denied", message: "Enable camera access in Settings.")
        @unknown default:
            break
        }
    }
    
    func requestGalleryAccess() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            openImagePicker(sourceType: .photoLibrary)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async {
                        self.openImagePicker(sourceType: .photoLibrary)
                    }
                }
            }
        case .denied, .restricted:
            showSettingsAlert(title: "Gallery Access Denied", message: "Enable photo library access in Settings.")
        @unknown default:
            break
        }
    }
    
    func openImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = sourceType
        imagePicker.allowsEditing = false
        imagePicker.mediaTypes = ["public.movie"]
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let videoURL = info[.mediaURL] as? URL {
            picker.dismiss(animated: true) { [weak self] in
                self?.setupVideoPlayer(with: videoURL)
                self?.filterButton.isEnabled = true
                self?.saveButton.isEnabled = true
                self?.filterButton.alpha = 1.0
                self?.saveButton.alpha = 1.0
            }
        } else {
            picker.dismiss(animated: true, completion: nil)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func showSettingsAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(settingsAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Select Filter", message: nil, preferredStyle: .actionSheet)
        
        for filter in filters {
            let action = UIAlertAction(title: filter, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = filter
                
                if let videoURL = self.currentVideoURL {
                    self.applyFilter(to: videoURL, filterName: filter)
                }
            }
            alertController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    private func applyFilter(to videoURL: URL, filterName: String) {
        let loadingAlert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 50),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 50)
        ])
        
        loadingAlert.view.heightAnchor.constraint(equalToConstant: 100).isActive = true
        loadingAlert.view.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        present(loadingAlert, animated: true, completion: nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if filterName == "Original" {
                self.filteredAsset = AVAsset(url: videoURL)
                self.currentTrimmedAsset = self.filteredAsset
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.setupVideoPlayer(with: videoURL)
                    }
                }
                return
            }
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsDirectory.appendingPathComponent("Filtered_temp_\(UUID().uuidString).mp4")
            
            let asset = AVAsset(url: videoURL)
            
            let composition = AVMutableComposition()
            
            guard let videoTrack = asset.tracks(withMediaType: .video).first,
                  let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid) else {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not create composition")
                    }
                }
                return
            }
            
            var compositionAudioTrack: AVMutableCompositionTrack?
            if let audioTrack = asset.tracks(withMediaType: .audio).first {
                compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid)
            }
            
            do {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                if let audioTrack = asset.tracks(withMediaType: .audio).first,
                   let compositionAudioTrack = compositionAudioTrack {
                    try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Failed to create composition: \(error.localizedDescription)")
                    }
                }
                return
            }
            
            let videoComposition = AVMutableVideoComposition(propertiesOf: asset)
            
            let filter = self.getCIFilter(for: filterName)
            self.compositionFilter = filter
            
            let ciContext = CIContext()
            
            videoComposition.renderSize = videoTrack.naturalSize
            videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
            
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                additionalLayer: CALayer(),
                asTrackID: kCMPersistentTrackID_Invalid)
            
            videoComposition.customVideoCompositorClass = CIFilterVideoCompositor.self
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            
            var transform = videoTrack.preferredTransform
            let videoInfo = orientation(from: transform)
            
            var videoSize = videoTrack.naturalSize
            if videoInfo.isPortrait {
                
                videoSize = CGSize(width: videoSize.height, height: videoSize.width)
                
                transform = CGAffineTransform(rotationAngle: .pi/2)
                transform = transform.translatedBy(x: videoSize.width, y: 0)
            }
            
            layerInstruction.setTransform(transform, at: .zero)
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            if let filterDescription = self.getFilterCompositorInfo(for: filterName) {
                FilterData.shared.currentFilterInfo = filterDescription
            }
            
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not create export session")
                    }
                }
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.videoComposition = videoComposition
            
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        switch exportSession.status {
                        case .completed:
                            self.filteredAsset = AVAsset(url: outputURL)
                            self.currentTrimmedAsset = self.filteredAsset
                            self.setupVideoPlayer(with: outputURL)
                        case .failed, .cancelled:
                            if let error = exportSession.error {
                                self.showAlert(title: "Export Failed", message: error.localizedDescription)
                            } else {
                                self.showAlert(title: "Export Failed", message: "Unknown error occurred")
                            }
                        default:
                            self.showAlert(title: "Export Failed", message: "Unknown error occurred")
                        }
                    }
                }
            }
        }
    }
    
    private func getCIFilter(for filterName: String) -> CIFilter? {
        switch filterName {
        case "Vivid":
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(1.3, forKey: kCIInputSaturationKey)
            filter?.setValue(0.3, forKey: kCIInputContrastKey)
            return filter
            
        case "Dramatic":
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(1.0, forKey: kCIInputSaturationKey)
            filter?.setValue(0.5, forKey: kCIInputContrastKey)
            filter?.setValue(0.1, forKey: kCIInputBrightnessKey)
            return filter
            
        case "Mono":
            return CIFilter(name: "CIPhotoEffectMono")
            
        case "Nashville":
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(1.2, forKey: kCIInputSaturationKey)
            filter?.setValue(0.2, forKey: kCIInputContrastKey)
            filter?.setValue(0.04, forKey: kCIInputBrightnessKey)
            return filter
            
        case "Toaster":
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(0.7, forKey: kCIInputIntensityKey)
            return filter
            
        case "1977":
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(1.3, forKey: kCIInputSaturationKey)
            filter?.setValue(0.2, forKey: kCIInputContrastKey)
            filter?.setValue(0.1, forKey: kCIInputBrightnessKey)
            return filter
            
        case "Noir":
            return CIFilter(name: "CIPhotoEffectNoir")
            
        case "Comic":
            return CIFilter(name: "CIComicEffect")
            
        case "Crystallize":
            let filter = CIFilter(name: "CICrystallize")
            filter?.setValue(20.0, forKey: kCIInputRadiusKey)
            return filter
            
        case "Bloom":
            let filter = CIFilter(name: "CIBloom")
            filter?.setValue(10.0, forKey: kCIInputRadiusKey)
            filter?.setValue(1.0, forKey: kCIInputIntensityKey)
            return filter
            
        case "Pixellate":
            let filter = CIFilter(name: "CIPixellate")
            filter?.setValue(10.0, forKey: kCIInputScaleKey)
            return filter
            
        case "Blur":
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(5.0, forKey: kCIInputRadiusKey)
            return filter
            
        case "Sepia":
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(0.8, forKey: kCIInputIntensityKey)
            return filter
            
        case "Fade":
            let filter = CIFilter(name: "CIPhotoEffectFade")
            return filter
            
        case "Sharpen":
            let filter = CIFilter(name: "CISharpenLuminance")
            filter?.setValue(0.5, forKey: kCIInputSharpnessKey)
            return filter
            
        case "HDR":
            let filter = CIFilter(name: "CIToneCurve")
            filter?.setValue(CIVector(x: 0.0, y: 0.0), forKey: "inputPoint0")
            filter?.setValue(CIVector(x: 0.25, y: 0.2), forKey: "inputPoint1")
            filter?.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
            filter?.setValue(CIVector(x: 0.75, y: 0.8), forKey: "inputPoint3")
            filter?.setValue(CIVector(x: 1.0, y: 1.0), forKey: "inputPoint4")
            return filter
            
        case "Vignette":
            let filter = CIFilter(name: "CIVignette")
            filter?.setValue(0.7, forKey: kCIInputIntensityKey)
            filter?.setValue(1.0, forKey: kCIInputRadiusKey)
            return filter
            
        case "Tonal":
            return CIFilter(name: "CIPhotoEffectTonal")
            
        case "Dot Matrix":
            let filter = CIFilter(name: "CIDotScreen")
            filter?.setValue(6.0, forKey: kCIInputWidthKey)
            filter?.setValue(6.0, forKey: kCIInputSharpnessKey)
            return filter
            
        case "Edge Work":
            return CIFilter(name: "CIEdges")
            
        case "X-Ray":
            return CIFilter(name: "CIColorInvert")
            
        case "Posterize":
            let filter = CIFilter(name: "CIColorPosterize")
            filter?.setValue(6.0, forKey: "inputLevels")
            return filter
            
        default:
            return nil
        }
    }
    
    private func getFilterCompositorInfo(for filterName: String) -> [String: Any]? {
        switch filterName {
        case "Vivid":
            return ["filterName": "CIColorControls",
                    "parameters": [kCIInputSaturationKey: 1.3, kCIInputContrastKey: 0.3]]
            
        case "Dramatic":
            return ["filterName": "CIColorControls",
                    "parameters": [kCIInputSaturationKey: 1.0, kCIInputContrastKey: 0.5, kCIInputBrightnessKey: 0.1]]
            
        case "Mono":
            return ["filterName": "CIPhotoEffectMono", "parameters": [:]]
            
        case "Nashville":
            return ["filterName": "CIColorControls",
                    "parameters": [kCIInputSaturationKey: 1.2, kCIInputContrastKey: 0.2, kCIInputBrightnessKey: 0.04]]
            
        case "Toaster":
            return ["filterName": "CISepiaTone", "parameters": [kCIInputIntensityKey: 0.7]]
            
        case "1977":
            return ["filterName": "CIColorControls",
                    "parameters": [kCIInputSaturationKey: 1.3, kCIInputContrastKey: 0.2, kCIInputBrightnessKey: 0.1]]
            
        case "Noir":
            return ["filterName": "CIPhotoEffectNoir", "parameters": [:]]
            
        case "Comic":
            return ["filterName": "CIComicEffect", "parameters": [:]]
            
        case "Crystallize":
            return ["filterName": "CICrystallize", "parameters": [kCIInputRadiusKey: 20.0]]
            
        case "Bloom":
            return ["filterName": "CIBloom", "parameters": [kCIInputRadiusKey: 10.0, kCIInputIntensityKey: 1.0]]
            
        case "Pixellate":
            return ["filterName": "CIPixellate", "parameters": [kCIInputScaleKey: 10.0]]
            
        case "Blur":
            return ["filterName": "CIGaussianBlur", "parameters": [kCIInputRadiusKey: 5.0]]
            
        case "Sepia":
            return ["filterName": "CISepiaTone", "parameters": [kCIInputIntensityKey: 0.8]]
            
        case "Fade":
            return ["filterName": "CIPhotoEffectFade", "parameters": [:]]
            
        case "Sharpen":
            return ["filterName": "CISharpenLuminance", "parameters": [kCIInputSharpnessKey: 0.5]]
            
        case "HDR":
            return ["filterName": "CIToneCurve", "parameters": [
                "inputPoint0": CIVector(x: 0.0, y: 0.0),
                "inputPoint1": CIVector(x: 0.25, y: 0.2),
                "inputPoint2": CIVector(x: 0.5, y: 0.5),
                "inputPoint3": CIVector(x: 0.75, y: 0.8),
                "inputPoint4": CIVector(x: 1.0, y: 1.0)
            ]]
            
        case "Vignette":
            return ["filterName": "CIVignette", "parameters": [kCIInputIntensityKey: 0.7, kCIInputRadiusKey: 1.0]]
            
        case "Tonal":
            return ["filterName": "CIPhotoEffectTonal", "parameters": [:]]
            
        case "Dot Matrix":
            return ["filterName": "CIDotScreen", "parameters": [kCIInputWidthKey: 6.0, kCIInputSharpnessKey: 6.0]]
            
        case "Edge Work":
            return ["filterName": "CIEdges", "parameters": [:]]
            
        case "X-Ray":
            return ["filterName": "CIColorInvert", "parameters": [:]]
            
        case "Posterize":
            return ["filterName": "CIColorPosterize", "parameters": ["inputLevels": 6.0]]
            
        default:
            return nil
        }
    }
    
    private func orientation(from transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        
        let tfA = transform.a
        let tfB = transform.b
        let tfC = transform.c
        let tfD = transform.d
        
        if tfA == 0 && tfB == 1.0 && tfC == -1.0 && tfD == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if tfA == 0 && tfB == -1.0 && tfC == 1.0 && tfD == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if tfA == 1.0 && tfB == 0 && tfC == 0 && tfD == 1.0 {
            assetOrientation = .up
        } else if tfA == -1.0 && tfB == 0 && tfC == 0 && tfD == -1.0 {
            assetOrientation = .down
        }
        
        return (assetOrientation, isPortrait)
    }
    
    class CIFilterVideoCompositor: NSObject, AVVideoCompositing {
        var requiredPixelBufferAttributesForRenderContext: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        var sourcePixelBufferAttributes: [String: Any]? = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        var ciContext = CIContext()
        private var currentVideoComposition: AVVideoComposition?
        
        func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
            currentVideoComposition = newRenderContext.videoComposition
        }
        
        func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
            guard let resultPixels = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
                asyncVideoCompositionRequest.finish(with: NSError(domain: "CIFilterVideoCompositor", code: -1, userInfo: nil))
                return
            }
            
            guard let sourcePixels = asyncVideoCompositionRequest.sourceFrame(byTrackID: asyncVideoCompositionRequest.sourceTrackIDs[0].int32Value) else {
                asyncVideoCompositionRequest.finish(with: NSError(domain: "CIFilterVideoCompositor", code: -1, userInfo: nil))
                return
            }
            
            let sourceCIImage = CIImage(cvPixelBuffer: sourcePixels)
            
            if let filterInfo = FilterData.shared.currentFilterInfo,
               let filterName = filterInfo["filterName"] as? String,
               let parameters = filterInfo["parameters"] as? [String: Any] {
                
                guard let filter = CIFilter(name: filterName) else {
                    asyncVideoCompositionRequest.finish(with: NSError(domain: "CIFilterVideoCompositor", code: -1, userInfo: nil))
                    return
                }
                
                filter.setValue(sourceCIImage, forKey: kCIInputImageKey)
                
                for (key, value) in parameters {
                    filter.setValue(value, forKey: key)
                }
                
                if let outputImage = filter.outputImage {
                    self.ciContext.render(outputImage, to: resultPixels)
                  //  asyncVideoCompositionRequest.finish(with: resultPixels)
                    return
                }
            }
            
            self.ciContext.render(sourceCIImage, to: resultPixels)
          //  asyncVideoCompositionRequest.finish(with: resultPixels)
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        if currentTrimmedAsset == nil && filteredAsset != nil {
            currentTrimmedAsset = filteredAsset
        } else if currentTrimmedAsset == nil, let videoURL = currentVideoURL {
            currentTrimmedAsset = AVAsset(url: videoURL)
        }
        
        guard let asset = currentTrimmedAsset else {
            showAlert(title: "Error", message: "No video available to save")
            return
        }
        
        let loadingAlert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 50),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 50)
        ])
        
        loadingAlert.view.heightAnchor.constraint(equalToConstant: 100).isActive = true
        loadingAlert.view.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        present(loadingAlert, animated: true, completion: nil)
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filterName = currentFilter.replacingOccurrences(of: " ", with: "_")
        let outputURL = documentsDirectory.appendingPathComponent("Filtered_\(filterName)_\(dateString).mp4")
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
            } catch {
                print("Could not remove existing file: \(error)")
            }
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            loadingAlert.dismiss(animated: true) {
                self.showAlert(title: "Error", message: "Could not create export session")
            }
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch exportSession.status {
                    case .completed:
                        self.saveVideoToLibrary(outputURL)
                    case .failed, .cancelled:
                        if let error = exportSession.error {
                            self.showAlert(title: "Export Failed", message: error.localizedDescription)
                        } else {
                            self.showAlert(title: "Export Failed", message: "Unknown error occurred")
                        }
                    default:
                        self.showAlert(title: "Export Failed", message: "Unknown error occurred")
                    }
                }
            }
        }
    }
    
    private func saveVideoToLibrary(_ videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.showAlert(title: "Success", message: "Video saved to your photo library")
                            do {
                                try FileManager.default.removeItem(at: videoURL)
                            } catch {
                                print("Could not remove temp file: \(error)")
                            }
                        } else {
                            if let error = error {
                                self.showAlert(title: "Save Failed", message: error.localizedDescription)
                            } else {
                                self.showAlert(title: "Save Failed", message: "Unknown error occurred")
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.showSettingsAlert(title: "Permission Denied", message: "To save videos, allow photo library access in Settings.")
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
}

