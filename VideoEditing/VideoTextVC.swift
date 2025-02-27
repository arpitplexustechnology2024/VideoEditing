//
//  VideoTextVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import UIKit
import AVFoundation
import Photos
import MobileCoreServices

class VideoTextVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false
    private var playPauseButton: UIButton!
    private var videoLooper: Any?
    private var currentTrimmedAsset: AVAsset?
    private var currentVideoURL: URL?
    
    private var textViews: [DraggableTextView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayPauseButton()
        setupUI()
        setupSwipeGesture()
        
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
    
    private func setupSwipeGesture() {
        let swipeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeGesture.edges = .left
        self.view.addGestureRecognizer(swipeGesture)
    }
    
    @objc private func handleSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .recognized {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func setupUI() {
        textButton.layer.cornerRadius = 10
        saveButton.layer.cornerRadius = 10
        
        textButton.isEnabled = false
        saveButton.isEnabled = false
        
        textButton.alpha = 0.5
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
    
    private func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showVideoPicker(for: .camera)
                    } else {
                        self?.showSettingsAlert(title: "Camera Access Denied", message: "Enable camera access in Settings.")
                    }
                }
            }
        case .authorized:
            showVideoPicker(for: .camera)
        case .denied, .restricted:
            showSettingsAlert(title: "Camera Access Denied", message: "Enable camera access in Settings.")
        @unknown default:
            break
        }
    }
    
    private func requestGalleryAccess() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.showVideoPicker(for: .photoLibrary)
                    } else {
                        self?.showSettingsAlert(title: "Gallery Access Denied", message: "Enable photo library access in Settings.")
                    }
                }
            }
        case .authorized, .limited:
            showVideoPicker(for: .photoLibrary)
        case .denied, .restricted:
            showSettingsAlert(title: "Gallery Access Denied", message: "Enable photo library access in Settings.")
        @unknown default:
            break
        }
    }
    
    private func showVideoPicker(for sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            print("Source type \(sourceType) is not available")
            return
        }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.mediaTypes = [kUTTypeMovie as String]
        
        picker.videoQuality = .typeHigh
        
        if sourceType == .camera {
            if let cameraDevice = AVCaptureDevice.default(for: .video) {
                do {
                    try cameraDevice.lockForConfiguration()
                    if cameraDevice.isExposureModeSupported(.continuousAutoExposure) {
                        cameraDevice.exposureMode = .continuousAutoExposure
                    }
                    if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                        cameraDevice.focusMode = .continuousAutoFocus
                    }
                    if cameraDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        cameraDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                    cameraDevice.unlockForConfiguration()
                } catch {
                    print("Camera configuration error: \(error)")
                }
            }
        }
        
        picker.allowsEditing = true
        picker.videoMaximumDuration = 15.0
        
        if #available(iOS 14.0, *) {
            picker.videoExportPreset = AVAssetExportPresetPassthrough
        }
        
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let videoURL = info[.mediaURL] as? URL {
            picker.dismiss(animated: true) { [weak self] in
                self?.setupVideoPlayer(with: videoURL)
                self?.textButton.isEnabled = true
                self?.saveButton.isEnabled = true
                self?.textButton.alpha = 1.0
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
    
    @IBAction func textButtonTapped(_ sender: UIButton) {
        let textEditorView = TextEditorView(frame: .zero)
        let containerView = UIView()
        
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        containerView.frame = view.bounds
        
        view.addSubview(containerView)
        containerView.addSubview(textEditorView)
        
        textEditorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textEditorView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            textEditorView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textEditorView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.85),
        ])
        
        textEditorView.onDismiss = {
            UIView.animate(withDuration: 0.3, animations: {
                containerView.alpha = 0
            }) { _ in
                containerView.removeFromSuperview()
            }
        }
        
        textEditorView.onAddText = { [weak self] text, color, font in
            self?.addTextToVideo(text, color: color, font: font)
        }
        
        containerView.alpha = 0
        textEditorView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3) {
            containerView.alpha = 1
            textEditorView.transform = .identity
        }
    }
    
    private func addTextToVideo(_ text: String, color: UIColor, font: UIFont) {
        let textView = DraggableTextView(text: text, textColor: color, font: font)
        textView.center = CGPoint(x: videoView.bounds.midX, y: videoView.bounds.midY)
        
        textView.onDelete = { [weak self, weak textView] in
            guard let textView = textView else { return }
            self?.removeTextView(textView)
        }
        
        videoView.addSubview(textView)
        videoView.bringSubviewToFront(textView)
        videoView.bringSubviewToFront(playPauseButton)
        textViews.append(textView)
    }
    
    private func removeTextView(_ textView: DraggableTextView) {
        textView.removeFromSuperview()
        if let index = textViews.firstIndex(of: textView) {
            textViews.remove(at: index)
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
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
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let audioTrack = asset.tracks(withMediaType: .audio).first else {
            loadingAlert.dismiss(animated: true) {
                self.showAlert(title: "Error", message: "Could not get video tracks")
            }
            return
        }
        
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do {
            let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            try compositionVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            
            try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            
            let videoComposition = getVideoCompositionWithText(composition: composition, videoTrack: videoTrack)
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = dateFormatter.string(from: Date())
            let outputURL = documentsDirectory.appendingPathComponent("TextVideo_\(dateString).mp4")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                loadingAlert.dismiss(animated: true) {
                    self.showAlert(title: "Error", message: "Could not create export session")
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
        } catch {
            loadingAlert.dismiss(animated: true) {
                self.showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }
    
    private func getVideoCompositionWithText(composition: AVComposition, videoTrack: AVAssetTrack) -> AVMutableVideoComposition {
        let originalSize = videoTrack.naturalSize
        
        let videoTransform = videoTrack.preferredTransform
        
        let videoInfo = orientation(from: videoTransform, videoSize: originalSize)
        let videoSize = videoInfo.size
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: composition.tracks(withMediaType: .video)[0])
        
        layerInstruction.setTransform(videoInfo.transform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        parentLayer.addSublayer(videoLayer)
        
        let textLayerParent = CALayer()
        textLayerParent.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        
        let videoViewAspect = videoView.bounds.width / videoView.bounds.height
        let videoAspect = videoSize.width / videoSize.height
        
        var videoRect = CGRect()
        if videoViewAspect > videoAspect {
            let height = videoView.bounds.height
            let width = height * videoAspect
            let x = (videoView.bounds.width - width) / 2
            videoRect = CGRect(x: x, y: 0, width: width, height: height)
        } else {
            let width = videoView.bounds.width
            let height = width / videoAspect
            let y = (videoView.bounds.height - height) / 2
            videoRect = CGRect(x: 0, y: y, width: width, height: height)
        }
        
        for textView in textViews {
            guard let textLabel = textView.subviews.first(where: { $0 is UILabel }) as? UILabel else {
                continue
            }
            
            let textLayer = CATextLayer()
            
            let viewPosition = textView.center
            
            let normalizedX = (viewPosition.x - videoRect.minX) / videoRect.width
            let normalizedY = (viewPosition.y - videoRect.minY) / videoRect.height
            
            var adjustedY = normalizedY
            
            if videoInfo.isPortrait {
                adjustedY = 1.0 - normalizedY
            }
            
            let textScale = min(videoSize.width / videoRect.width, videoSize.height / videoRect.height)
            let textWidth = textView.bounds.width * textScale
            let textHeight = textView.bounds.height * textScale
            
            let textX = normalizedX * videoSize.width - (textWidth / 2)
            let textY = adjustedY * videoSize.height - (textHeight / 2)
            
            textLayer.frame = CGRect(
                x: textX,
                y: textY,
                width: textWidth,
                height: textHeight
            )
            
            textLayer.string = textLabel.text
            textLayer.font = CGFont(textLabel.font.fontName as CFString)
            textLayer.fontSize = textLabel.font.pointSize * textScale
            textLayer.foregroundColor = textLabel.textColor.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.isWrapped = true
            
            textLayerParent.addSublayer(textLayer)
        }
        
        parentLayer.addSublayer(textLayerParent)
        
        let animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        videoComposition.animationTool = animationTool
        
        return videoComposition
    }
    
    private func orientation(from transform: CGAffineTransform, videoSize: CGSize) -> (size: CGSize, transform: CGAffineTransform, isPortrait: Bool) {
        let videoSize = videoSize
        var transform = transform
        var isPortrait = false
        
        if transform.b == 1.0 && transform.c == -1.0 {
            let rotatedSize = CGSize(width: videoSize.height, height: videoSize.width)
            
            transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: rotatedSize.width, ty: 0)
            isPortrait = true
            
            return (rotatedSize, transform, isPortrait)
        } else if transform.a == -1.0 && transform.d == -1.0 {
            transform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: videoSize.width, ty: videoSize.height)
            
            return (videoSize, transform, isPortrait)
        } else if transform.b == -1.0 && transform.c == 1.0 {
            let rotatedSize = CGSize(width: videoSize.height, height: videoSize.width)
            
            transform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: rotatedSize.height)
            isPortrait = true
            
            return (rotatedSize, transform, isPortrait)
        }
        
        return (videoSize, transform, isPortrait)
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

