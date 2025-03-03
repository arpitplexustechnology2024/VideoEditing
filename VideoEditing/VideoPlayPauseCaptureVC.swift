//
//  VideoPlayPauseCaptureVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 03/03/25.
//

import UIKit
import AVFoundation

// MARK: - VideoCaptureVC
@available(iOS 18.0, *)
class VideoPlayPauseCaptureVC: UIViewController {
    
    private var captureSession: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let recordButton = UIButton(type: .custom)
    private let recordButtonInner = UIButton(type: .custom)
    private let switchCameraButton = UIButton(type: .system)
    private let timerLabel = UILabel()
    private let torchButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    
    private var isRecording = false
    private var isPaused = false
    private var isFrontCameraActive = false
    private var isTorchActive = false
    private var outputFileURL: URL?
    
    private var recordingTimer: Timer?
    private var elapsedSeconds = 0
    private var longPressGesture: UILongPressGestureRecognizer!
    private var progressLayer: CAShapeLayer?
    private var recordingStartTime: Date?
    private var displayLink: CADisplayLink?
    
    private let normalButtonSize: CGFloat = 70
    private let recordingButtonSize: CGFloat = 100
    private let normalInnerButtonSize: CGFloat = 60
    private let recordingInnerButtonSize: CGFloat = 25
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCaptureSession()
        setupLongPressGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCaptureSession()
        if isTorchActive {
            isTorchActive = false
            updateTorchButtonIcon()
        }
        resetTimer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateTorchStateFromDevice()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
        stopTimer()
        if isTorchActive {
            toggleTorch(on: false)
        }
    }
    
    private func setupLongPressGesture() {
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.3
        recordButton.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            if !isRecording {
                startRecording()
            } else if isPaused {
                resumeRecording()
            }
        case .ended, .cancelled, .failed:
            if isRecording && !isPaused {
                pauseRecording()
            }
        default:
            break
        }
    }
    
    // MARK: - UI Setup Method
    private func setupUI() {
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.text = "00:00"
        timerLabel.textColor = .white
        timerLabel.textAlignment = .center
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        timerLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        timerLabel.layer.cornerRadius = 10
        timerLabel.clipsToBounds = true
        timerLabel.isHidden = true
        
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.backgroundColor = .clear
        recordButton.layer.cornerRadius = normalButtonSize / 2
        recordButton.layer.borderColor = UIColor.white.cgColor
        recordButton.layer.borderWidth = 3
        
        recordButtonInner.translatesAutoresizingMaskIntoConstraints = false
        recordButtonInner.backgroundColor = .white
        recordButtonInner.layer.cornerRadius = normalInnerButtonSize / 2
        
        setupProgressLayer()
        
        switchCameraButton.setImage(UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        switchCameraButton.layer.cornerRadius = 22
        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
        
        torchButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        torchButton.tintColor = .white
        torchButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        torchButton.layer.cornerRadius = 22
        torchButton.translatesAutoresizingMaskIntoConstraints = false
        torchButton.addTarget(self, action: #selector(torchButtonTapped), for: .touchUpInside)
        torchButton.isHidden = isFrontCameraActive
        
        doneButton.setTitle("Done", for: .normal)
        doneButton.tintColor = .black
        doneButton.backgroundColor = UIColor.white
        doneButton.layer.cornerRadius = 22
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        doneButton.isHidden = true
        
        view.addSubview(recordButton)
        recordButton.addSubview(recordButtonInner)
        view.addSubview(switchCameraButton)
        view.addSubview(timerLabel)
        view.addSubview(torchButton)
        view.addSubview(doneButton)
        
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            recordButton.widthAnchor.constraint(equalToConstant: normalButtonSize),
            recordButton.heightAnchor.constraint(equalToConstant: normalButtonSize),
            
            recordButtonInner.centerXAnchor.constraint(equalTo: recordButton.centerXAnchor),
            recordButtonInner.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            recordButtonInner.widthAnchor.constraint(equalToConstant: normalInnerButtonSize),
            recordButtonInner.heightAnchor.constraint(equalToConstant: normalInnerButtonSize),
            
            switchCameraButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -42),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 44),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 44),
            
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            timerLabel.heightAnchor.constraint(equalToConstant: 36),
            
            torchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            torchButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            torchButton.widthAnchor.constraint(equalToConstant: 44),
            torchButton.heightAnchor.constraint(equalToConstant: 44),
            
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -42),
            doneButton.widthAnchor.constraint(equalToConstant: 70),
            doneButton.heightAnchor.constraint(equalToConstant: 44),
        ])
        
        timerLabel.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    private func setupProgressLayer() {
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: normalButtonSize/2, y: normalButtonSize/2),
                                        radius: normalButtonSize/2,
                                        startAngle: -CGFloat.pi / 2,
                                        endAngle: 3 * CGFloat.pi / 2,
                                        clockwise: true)
        
        progressLayer = CAShapeLayer()
        progressLayer?.path = circularPath.cgPath
        progressLayer?.strokeColor = UIColor.red.cgColor
        progressLayer?.fillColor = UIColor.clear.cgColor
        progressLayer?.lineWidth = 3
        progressLayer?.strokeEnd = 0
        progressLayer?.lineCap = .round
        
        recordButton.layer.insertSublayer(progressLayer!, above: recordButton.layer)
    }
    
    private func updateProgressBar() {
        guard let startTime = recordingStartTime else { return }
        
        let elapsedTime = -startTime.timeIntervalSinceNow
        let progress = min(Float(elapsedTime / 60.0), 1.0)
        
        progressLayer?.strokeEnd = CGFloat(progress)
        
        if progress >= 1.0 {
            resetProgress()
        }
    }
    
    private func resetProgress() {
        recordingStartTime = Date()
        progressLayer?.strokeEnd = 0
    }
    
    private func startProgressAnimation() {
        recordingStartTime = Date()
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateProgressAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateProgressAnimation() {
        updateProgressBar()
    }
    
    private func pauseProgressAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func resumeProgressAnimation() {
        if let originalStartTime = recordingStartTime {
            let pausedTime = -originalStartTime.timeIntervalSinceNow
            recordingStartTime = Date().addingTimeInterval(-pausedTime)
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateProgressAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    // MARK: - Camera Setup Methods
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        setupAudioInput()
        configureCameraInput(position: .back)
        configureVideoOutput()
        setupPreviewLayer()
    }
    
    private func setupAudioInput() {
        guard let captureSession = captureSession else { return }
        
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Audio device not found")
            return
        }
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                audioDeviceInput = audioInput
                print("Audio input added successfully")
            } else {
                print("Could not add audio input")
            }
        } catch {
            print("Audio input setup error: \(error.localizedDescription)")
        }
    }
    
    private func configureCameraInput(position: AVCaptureDevice.Position) {
        guard let captureSession = captureSession else { return }
        
        let wasRecording = isRecording
        var savedFileURL: URL? = nil
        
        if wasRecording, let videoOutput = videoOutput {
            savedFileURL = outputFileURL
            videoOutput.stopRecording()
            isRecording = false
        }
        
        if captureSession.isRunning {
            captureSession.beginConfiguration()
        }
        
        if let existingInput = videoDeviceInput {
            captureSession.removeInput(existingInput)
        }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            if captureSession.isRunning {
                captureSession.commitConfiguration()
            }
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                videoDeviceInput = videoInput
                
                let previousCameraPosition = isFrontCameraActive ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
                isFrontCameraActive = position == .front
                
                configureVideoOutput()
                
                if isFrontCameraActive {
                    torchButton.isHidden = true
                    if isTorchActive {
                        isTorchActive = false
                        toggleTorch(on: false)
                    }
                } else {
                    torchButton.isHidden = false
                    
                    if previousCameraPosition == .front {
                        isTorchActive = false
                        updateTorchButtonIcon()
                    }
                }
            }
        } catch {
            print("Camera input setup error: \(error.localizedDescription)")
        }
        
        if captureSession.isRunning {
            captureSession.commitConfiguration()
        }
        
        if wasRecording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startRecording(continueFromURL: savedFileURL)
            }
        }
    }
    
    private func configureVideoOutput() {
        guard let captureSession = captureSession else { return }
        
        if let existingOutput = videoOutput {
            captureSession.removeOutput(existingOutput)
        }
        
        let movieOutput = AVCaptureMovieFileOutput()
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = isFrontCameraActive
                }
            }
            
            if let audioConnection = movieOutput.connection(with: .audio) {
                audioConnection.isEnabled = true
            }
            
            videoOutput = movieOutput
        }
    }
    
    private func setupPreviewLayer() {
        guard let captureSession = captureSession else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        
        self.previewLayer = previewLayer
    }
    
    private func startCaptureSession() {
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }
    
    private func stopCaptureSession() {
        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Torch State Management
    private func updateTorchStateFromDevice() {
        guard let device = AVCaptureDevice.default(for: .video),
              !isFrontCameraActive,
              device.hasTorch else {
            return
        }
        
        let actualTorchState = device.torchMode == .on
        if isTorchActive != actualTorchState {
            isTorchActive = actualTorchState
            updateTorchButtonIcon()
        }
    }
    
    // MARK: - Timer Methods
    private func startTimer() {
        elapsedSeconds = 0
        updateTimerLabel()
        timerLabel.isHidden = false
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedSeconds += 1
            self.updateTimerLabel()
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func resetTimer() {
        elapsedSeconds = 0
        timerLabel.text = "00:00"
        timerLabel.isHidden = true
    }
    
    private func updateTimerLabel() {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Recording Methods
    @objc private func doneButtonTapped() {
        if isRecording, outputFileURL != nil {
            stopRecording()
            resetTimer()
            showPreviewScreen()
        }
    }
    
    private func showPreviewScreen() {
        guard let outputFileURL = outputFileURL else { return }
        
        DispatchQueue.main.async {
            if let storyboard = self.storyboard {
                if let previewVC = storyboard.instantiateViewController(identifier: "VideoCaptureShowVC") as? VideoCaptureShowVC {
                    previewVC.videoURL = outputFileURL
                    previewVC.modalPresentationStyle = .fullScreen
                    self.present(previewVC, animated: true)
                } else {
                    print("Could not instantiate VideoCaptureShowVC")
                }
            }
        }
    }
    
    @objc private func switchCameraTapped() {
        let newPosition: AVCaptureDevice.Position = isFrontCameraActive ? .back : .front
        
        configureCameraInput(position: newPosition)
    }
    
    @objc private func torchButtonTapped() {
        toggleTorch(on: !isTorchActive)
    }
    
    private func updateTorchButtonIcon() {
        let iconName = isTorchActive ? "bolt.fill" : "bolt.slash.fill"
        torchButton.setImage(UIImage(systemName: iconName), for: .normal)
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              !isFrontCameraActive,
              device.hasTorch,
              device.isTorchAvailable else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            
            device.unlockForConfiguration()
            isTorchActive = on
            
            updateTorchButtonIcon()
            
        } catch {
            print("Torch could not be used: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Modified startRecording method
    func startRecording(continueFromURL: URL? = nil) {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "video_\(Date().timeIntervalSince1970).mov"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Could not remove file: \(error.localizedDescription)")
        }
        
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCameraActive
            }
        }
        
        videoOutput.startRecording(to: fileURL, recordingDelegate: self)
        
        progressLayer?.strokeColor = UIColor.red.cgColor
        
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: normalButtonSize/2, y: normalButtonSize/2),
                                        radius: normalButtonSize/2,
                                        startAngle: -CGFloat.pi / 2,
                                        endAngle: 3 * CGFloat.pi / 2,
                                        clockwise: true)
        progressLayer?.path = circularPath.cgPath
        
        startProgressAnimation()
        
        isRecording = true
        isPaused = false
        outputFileURL = fileURL
        doneButton.isHidden = false
        
        UIView.animate(withDuration: 0.3) {
            self.recordButton.transform = CGAffineTransform(scaleX: self.recordingButtonSize/self.normalButtonSize,
                                                            y: self.recordingButtonSize/self.normalButtonSize)
            self.recordButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            
            self.recordButtonInner.layer.cornerRadius = 6
            self.recordButtonInner.transform = CGAffineTransform(scaleX: self.recordingInnerButtonSize/self.normalInnerButtonSize,
                                                                 y: self.recordingInnerButtonSize/self.normalInnerButtonSize)
            
            self.recordButton.layer.borderWidth = 0
            self.recordButton.layer.borderColor = UIColor.clear.cgColor
        }
        
        if continueFromURL == nil {
            startTimer()
        }
    }
    
    func pauseRecording() {
        guard isRecording, !isPaused, let videoOutput = videoOutput else { return }
        
        videoOutput.pauseRecording()
        isPaused = true
        pauseProgressAnimation()
        
        progressLayer?.strokeColor = UIColor.red.cgColor
        
        UIView.animate(withDuration: 0.3) {
            self.recordButton.transform = .identity
            self.recordButton.backgroundColor = .clear
            
            let circularPath = UIBezierPath(arcCenter: CGPoint(x: self.normalButtonSize/2, y: self.normalButtonSize/2),
                                            radius: self.normalButtonSize/2,
                                            startAngle: -CGFloat.pi / 2,
                                            endAngle: 3 * CGFloat.pi / 2,
                                            clockwise: true)
            self.progressLayer?.path = circularPath.cgPath
            
            self.recordButtonInner.layer.cornerRadius = self.normalInnerButtonSize/2
            self.recordButtonInner.transform = .identity
            
            self.recordButton.layer.borderColor = UIColor.clear.cgColor
            self.recordButton.layer.borderWidth = 0
        }
        
        recordingTimer?.invalidate()
    }
    
    func resumeRecording() {
        guard isRecording, isPaused, let videoOutput = videoOutput else { return }
        
        videoOutput.resumeRecording()
        isPaused = false
        
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: normalButtonSize/2, y: normalButtonSize/2),
                                        radius: normalButtonSize/2,
                                        startAngle: -CGFloat.pi / 2,
                                        endAngle: 3 * CGFloat.pi / 2,
                                        clockwise: true)
        progressLayer?.path = circularPath.cgPath
        
        resumeProgressAnimation()
        
        progressLayer?.strokeColor = UIColor.red.cgColor
        
        UIView.animate(withDuration: 0.3) {
            self.recordButton.transform = CGAffineTransform(scaleX: self.recordingButtonSize/self.normalButtonSize,
                                                            y: self.recordingButtonSize/self.normalButtonSize)
            self.recordButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            
            self.recordButtonInner.layer.cornerRadius = 6
            self.recordButtonInner.transform = CGAffineTransform(scaleX: self.recordingInnerButtonSize/self.normalInnerButtonSize,
                                                                 y: self.recordingInnerButtonSize/self.normalInnerButtonSize)
            
            self.recordButton.layer.borderColor = UIColor.clear.cgColor
            self.recordButton.layer.borderWidth = 0
        }
        
        startTimerFromCurrentElapsed()
    }
    
    private func startTimerFromCurrentElapsed() {
        updateTimerLabel()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedSeconds += 1
            self.updateTimerLabel()
        }
    }
    
    // MARK: - Modified stopRecording
    @available(iOS 18.0, *)
    func stopRecording() {
        guard let videoOutput = videoOutput, isRecording else { return }
        
        if isPaused {
            videoOutput.resumeRecording()
            isPaused = false
        }
        
        videoOutput.stopRecording()
        
        progressLayer?.strokeEnd = 0
        displayLink?.invalidate()
        displayLink = nil
        
        UIView.animate(withDuration: 0.3) {
            self.recordButton.transform = .identity
            self.recordButton.backgroundColor = .clear
            
            let circularPath = UIBezierPath(arcCenter: CGPoint(x: self.normalButtonSize/2, y: self.normalButtonSize/2),
                                            radius: self.normalButtonSize/2,
                                            startAngle: -CGFloat.pi / 2,
                                            endAngle: 3 * CGFloat.pi / 2,
                                            clockwise: true)
            self.progressLayer?.path = circularPath.cgPath
            
            self.recordButtonInner.layer.cornerRadius = self.normalInnerButtonSize/2
            self.recordButtonInner.transform = .identity
            
            self.recordButton.layer.borderColor = UIColor.white.cgColor
            self.recordButton.layer.borderWidth = 3
        }
        
        isRecording = false
        stopTimer()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate Extension
@available(iOS 18.0, *)
extension VideoPlayPauseCaptureVC: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Recording started")
    }
    
    // MARK: - Modified fileOutput completion
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if isRecording {
            return
        }
        
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
            return
        }
        
        if isTorchActive {
            toggleTorch(on: false)
        }
    }
}
