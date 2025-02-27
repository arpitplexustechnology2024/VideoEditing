//
//  VideoFilterVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import UIKit
import AVFoundation
import Photos
import MobileCoreServices

class VideoFilterVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false
    private var playPauseButton: UIButton!
    private var videoLooper: Any?
    private var currentTrimmedAsset: AVAsset?
    private var currentVideoURL: URL?
    private var originalVideoURL: URL?
    
    private let filters = ["Original", "Vivid", "Dramatic", "Mono", "Nashville", "Toaster", "1977", "Noir", "Sepia", "Fade", "Sharpen", "Vignette", "Tonal"]
    
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
        
        if originalVideoURL == nil {
            originalVideoURL = url
        }
        
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
                self?.originalVideoURL = videoURL
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
        guard let asset = currentTrimmedAsset else {
            showAlert(title: "Error", message: "Please first select video!")
            return
        }
        
        let alertController = UIAlertController(title: "Filter Select", message: nil, preferredStyle: .actionSheet)
        
        for filterName in filters {
            let action = UIAlertAction(title: filterName, style: .default) { [weak self] _ in
                self?.applyFilter(filterName, to: asset)
            }
            alertController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func applyFilter(_ filterName: String, to asset: AVAsset) {
        if filterName == "Original" {
            if let currentVideoURL = originalVideoURL {
                setupVideoPlayer(with: currentVideoURL)
            }
            return
        }
        
        guard let originalVideoURL = self.originalVideoURL else {
            showAlert(title: "Error", message: "Original video not found!")
            return
        }
        
        let originalAsset = AVAsset(url: originalVideoURL)
        
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
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsDirectory.appendingPathComponent("FilteredVideo_\(UUID().uuidString).mp4")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            let composition = AVMutableComposition()
            
            guard let videoTrack = originalAsset.tracks(withMediaType: .video).first,
                  let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Failed to get video track!")
                    }
                }
                return
            }
            
            do {
                if let audioTrack = originalAsset.tracks(withMediaType: .audio).first,
                   let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    let timeRange = CMTimeRange(start: .zero, duration: originalAsset.duration)
                    try audioCompositionTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
            } catch {
                print("Error copying audio track: \(error)")
            }
            
            do {
                let timeRange = CMTimeRange(start: .zero, duration: originalAsset.duration)
                try compositionTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                guard let filter = self.createFilter(name: filterName) else {
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            self.showAlert(title: "Error", message: "Could not create filter!")
                        }
                    }
                    return
                }
                
                let videoComposition = AVMutableVideoComposition(asset: originalAsset) { [weak filter] request in
                    guard let filter = filter else {
                        request.finish(with: request.sourceImage, context: nil)
                        return
                    }
                    
                    let source = request.sourceImage.clampedToExtent()
                    filter.setValue(source, forKey: kCIInputImageKey)
                    
                    guard let outputImage = filter.outputImage else {
                        request.finish(with: request.sourceImage, context: nil)
                        return
                    }
                    
                    request.finish(with: outputImage, context: nil)
                }
                
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            self.showAlert(title: "Error", message: "Failed to create export session!")
                        }
                    }
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.videoComposition = videoComposition
                exportSession.timeRange = CMTimeRange(start: .zero, duration: originalAsset.duration)
                
                let exportGroup = DispatchGroup()
                exportGroup.enter()
                
                exportSession.exportAsynchronously {
                    exportGroup.leave()
                }
                
                let waitResult = exportGroup.wait(timeout: .now() + 60)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        if waitResult == .timedOut {
                            exportSession.cancelExport()
                            self.showAlert(title: "Filter application timed out", message: "Please select a smaller video or try again")
                            return
                        }
                        
                        switch exportSession.status {
                        case .completed:
                            self.setupVideoPlayer(with: outputURL)
                            self.currentVideoURL = outputURL
                            self.currentTrimmedAsset = AVAsset(url: outputURL)
                            
                        case .failed:
                            if let error = exportSession.error {
                                print("Filter error: \(error.localizedDescription)")
                                
                                if error.localizedDescription.contains("Cannot Decode") || error.localizedDescription.contains("decode") {
                                    self.showAlert(title: "Filter application failed", message: "Problem with video format. Please select a different video.")
                                } else if error.localizedDescription.contains("out of memory") || error.localizedDescription.contains("memory") {
                                    self.showAlert(title: "Memory Error", message: "Video is too large. Please select a smaller video.")
                                } else {
                                    self.showAlert(title: "Filter application failed", message: "Please try again: \(error.localizedDescription)")
                                }
                            } else {
                                self.showAlert(title: "Filter application failed", message: "Unknown error occurred, please try again")
                            }
                            
                        case .cancelled:
                            self.showAlert(title: "Filter process canceled", message: "The filter application process was canceled")
                            
                        default:
                            self.showAlert(title: "Filter application failed", message: "Unknown error occurred, please try again")
                        }
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Failed to apply filter to video: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func createFilter(name: String) -> CIFilter? {
        switch name {
        case "Vivid":
            return CIFilter(name: "CIPhotoEffectChrome")
        case "Dramatic":
            return CIFilter(name: "CIPhotoEffectTransfer")
        case "Mono":
            return CIFilter(name: "CIPhotoEffectMono")
        case "Nashville":
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(0.8, forKey: kCIInputIntensityKey)
            return filter
        case "Toaster":
            return CIFilter(name: "CIPhotoEffectInstant")
        case "1977":
            return CIFilter(name: "CIPhotoEffectProcess")
        case "Noir":
            return CIFilter(name: "CIPhotoEffectNoir")
        case "Sepia":
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(0.7, forKey: kCIInputIntensityKey)
            return filter
        case "Fade":
            return CIFilter(name: "CIPhotoEffectFade")
        case "Sharpen":
            let filter = CIFilter(name: "CISharpenLuminance")
            filter?.setValue(1.0, forKey: kCIInputSharpnessKey)
            return filter
        case "Vignette":
            let filter = CIFilter(name: "CIVignette")
            filter?.setValue(1.0, forKey: kCIInputIntensityKey)
            filter?.setValue(2.0, forKey: kCIInputRadiusKey)
            return filter
        case "Tonal":
            return CIFilter(name: "CIPhotoEffectTonal")
        default:
            return nil
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
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let outputURL = documentsDirectory.appendingPathComponent("TrimmedVideo_\(dateString).mp4")
        
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
