//
//  VideoStickerVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import UIKit
import AVFoundation
import Photos
import AVKit

class VideoStickerVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var stickerButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
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
        stickerButton.layer.cornerRadius = 10
        saveButton.layer.cornerRadius = 10
        
        stickerButton.isEnabled = false
        saveButton.isEnabled = false
        
        stickerButton.alpha = 0.5
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
                self?.stickerButton.isEnabled = true
                self?.saveButton.isEnabled = true
                self?.stickerButton.alpha = 1.0
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
    
    // MARK: - stickerButtonTapped
    @IBAction func stickerButtonTapped(_ sender: UIButton) {
        let stickerBottomView = StickerBottomView()
        
        stickerBottomView.onStickerSelected = { [weak self] image in
            self?.addStickerToImage(image)
        }
        
        present(stickerBottomView, animated: true)
    }
    
    // MARK: - saveButtonTapped
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        
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
        
        present(loadingAlert, animated: true) {
            self.exportVideoWithStickers { result in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        switch result {
                        case .success(let outputURL):
                            self.saveVideoToLibrary(outputURL)
                        case .failure(let error):
                            self.showAlert(title: "Export Failed", message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Video Export with Stickers
    private func exportVideoWithStickers(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let asset = currentTrimmedAsset, let currentVideoURL = currentVideoURL else {
            completion(.failure(NSError(domain: "VideoStickerVC", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video available"])))
            return
        }
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(NSError(domain: "VideoStickerVC", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])))
            return
        }
        
        var compositionAudioTrack: AVMutableCompositionTrack?
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        }
        
        do {
            let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            
            if let audioTrack = asset.tracks(withMediaType: .audio).first,
               let compositionAudioTrack = compositionAudioTrack {
                try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }
            
            let videoTransform = videoTrack.preferredTransform
            var naturalSize = videoTrack.naturalSize
            
            let isVideoPortrait = (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) ||
            (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0)
            
            if isVideoPortrait {
                naturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            }
            
            let videoComposition = AVMutableVideoComposition()
            videoComposition.renderSize = naturalSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRange
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            let captureStickersOnVideoFrames = { [weak self] (asset: AVAsset, videoComposition: AVMutableVideoComposition) in
                guard let self = self else { return }
                
                let overlayLayer = CALayer()
                overlayLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
                
                let parentLayer = CALayer()
                parentLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
                
                let videoLayer = CALayer()
                videoLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
                
                parentLayer.addSublayer(videoLayer)
                parentLayer.addSublayer(overlayLayer)
                
                let stickerViews = self.stickerViews
                
                for stickerView in stickerViews {
                    let stickerLayer = CALayer()
                    
                    let videoViewSize = self.videoView.bounds.size
                    let videoSize = videoComposition.renderSize
                    
                    let widthRatio = videoSize.width / videoViewSize.width
                    let heightRatio = videoSize.height / videoViewSize.height
                    
                    let stickerCenter = stickerView.center
                    let stickerSize = stickerView.bounds.size
                    
                    let invertedY = videoViewSize.height - stickerCenter.y
                    
                    let stickerRect = CGRect(
                        x: (stickerCenter.x / videoViewSize.width) * videoSize.width - (stickerSize.width * widthRatio) / 2,
                        y: (invertedY / videoViewSize.height) * videoSize.height - (stickerSize.height * heightRatio) / 2,
                        width: stickerSize.width * widthRatio,
                        height: stickerSize.height * heightRatio
                    )
                    
                    UIGraphicsBeginImageContextWithOptions(stickerView.bounds.size, false, 0.0)
                    let context = UIGraphicsGetCurrentContext()!
                    stickerView.layer.render(in: context)
                    let stickerImage = UIGraphicsGetImageFromCurrentImageContext()!
                    UIGraphicsEndImageContext()
                    
                    stickerLayer.contents = stickerImage.cgImage
                    stickerLayer.frame = stickerRect
                    
                    let transform = stickerView.transform
                    let rotation = atan2(transform.b, transform.a)
                    let scaleX = sqrt(transform.a * transform.a + transform.b * transform.b)
                    let scaleY = sqrt(transform.c * transform.c + transform.d * transform.d)
                    
                    var layerTransform = CATransform3DIdentity
                    layerTransform = CATransform3DRotate(layerTransform, rotation, 0, 0, 1)
                    layerTransform = CATransform3DScale(layerTransform, scaleX, scaleY, 1.0)
                    
                    stickerLayer.transform = layerTransform
                    
                    overlayLayer.addSublayer(stickerLayer)
                }
                
                videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                    postProcessingAsVideoLayer: videoLayer,
                    in: parentLayer
                )
            }
            
            captureStickersOnVideoFrames(asset, videoComposition)
            
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                completion(.failure(NSError(domain: "VideoStickerVC", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])))
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.videoComposition = videoComposition
            exportSession.shouldOptimizeForNetworkUse = true
            
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    if let error = exportSession.error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(NSError(domain: "VideoStickerVC", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"])))
                    }
                case .cancelled:
                    completion(.failure(NSError(domain: "VideoStickerVC", code: 5, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"])))
                default:
                    completion(.failure(NSError(domain: "VideoStickerVC", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unknown export status"])))
                }
            }
            
        } catch {
            completion(.failure(error))
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

//MARK: - Sticker
extension VideoStickerVC {
    private var stickerViews: [DraggableStickerView] {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.stickerViewsKey) as? [DraggableStickerView] ?? []
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.stickerViewsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func addStickerToImage(_ image: UIImage) {
        let stickerView = DraggableStickerView(image: image)
        stickerView.center = CGPoint(x: videoView.bounds.midX, y: videoView.bounds.midY)
        
        stickerView.onDelete = { [weak self, weak stickerView] in
            guard let stickerView = stickerView else { return }
            self?.removeStickerView(stickerView)
        }
        
        videoView.addSubview(stickerView)
        
        var currentStickerViews = self.stickerViews
        currentStickerViews.append(stickerView)
        self.stickerViews = currentStickerViews
    }
    
    private func removeStickerView(_ stickerView: DraggableStickerView) {
        stickerView.removeFromSuperview()
        
        var currentStickerViews = self.stickerViews
        if let index = currentStickerViews.firstIndex(where: { $0 === stickerView }) {
            currentStickerViews.remove(at: index)
            self.stickerViews = currentStickerViews
        }
    }
}
