//
//  VideoCaptureVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 28/02/25.
//

import UIKit
import AVFoundation

// MARK: - VideoCaptureVC
class VideoCaptureVC: UIViewController {
    
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
    
    private var isRecording = false
    private var isFrontCameraActive = false
    private var isTorchActive = false
    private var outputFileURL: URL?
    
    private var recordingTimer: Timer?
    private var elapsedSeconds = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCaptureSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCaptureSession()
        if isTorchActive {
            isTorchActive = false
            updateTorchButtonIcon()
        }
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
        recordButton.layer.cornerRadius = 35
        recordButton.layer.borderColor = UIColor.white.cgColor
        recordButton.layer.borderWidth = 3
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        
        recordButtonInner.translatesAutoresizingMaskIntoConstraints = false
        recordButtonInner.backgroundColor = .red
        recordButtonInner.layer.cornerRadius = 30
        recordButtonInner.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        
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
        
        view.addSubview(recordButton)
        view.addSubview(switchCameraButton)
        view.addSubview(timerLabel)
        view.addSubview(torchButton)
        recordButton.addSubview(recordButtonInner)
        
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            recordButton.widthAnchor.constraint(equalToConstant: 70),
            recordButton.heightAnchor.constraint(equalToConstant: 70),
            
            recordButtonInner.centerXAnchor.constraint(equalTo: recordButton.centerXAnchor),
            recordButtonInner.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            recordButtonInner.widthAnchor.constraint(equalToConstant: 60),
            recordButtonInner.heightAnchor.constraint(equalToConstant: 60),
            
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
            torchButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        timerLabel.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
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
        timerLabel.isHidden = true
    }
    
    private func updateTimerLabel() {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Button Action Methods
    @objc private func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
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
    
    // MARK: - Recording Methods
    private func startRecording(continueFromURL: URL? = nil) {
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
        
        UIView.animate(withDuration: 0.3) {
            self.recordButtonInner.layer.cornerRadius = 6
            self.recordButtonInner.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        
        isRecording = true
        outputFileURL = fileURL
        
        if continueFromURL == nil {
            startTimer()
        }
    }
    
    private func stopRecording() {
        guard let videoOutput = videoOutput, isRecording else { return }
        videoOutput.stopRecording()
        
        UIView.animate(withDuration: 0.3) {
            self.recordButtonInner.layer.cornerRadius = 30
            self.recordButtonInner.transform = .identity
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
extension VideoCaptureVC: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Recording started")
    }
    
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
        
        print("Recording successfully saved: \(outputFileURL.path)")
        
        DispatchQueue.main.async {
            if let storyboard = self.storyboard {
                if let previewVC = storyboard.instantiateViewController(identifier: "VideoCaptureShowVC") as? VideoCaptureShowVC {
                    previewVC.videoURL = outputFileURL
                    previewVC.modalPresentationStyle = .fullScreen
                    self.present(previewVC, animated: true)
                } else {
                    print("Could not instantiate VideoCaptureShowVC")
                }
            } else {
                print("Storyboard not available")
            }
        }
    }
}
