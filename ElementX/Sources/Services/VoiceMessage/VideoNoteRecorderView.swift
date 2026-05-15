//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Compound
import Foundation
import SwiftUI

struct VideoNoteRecorderView: View {
    let command: RoomRecordingOverlayController.VideoRecorderCommand?
    let isLocked: Bool
    var onLock: () -> Void = { }
    var onFinish: (URL) -> Void
    var onCancel: () -> Void = { }
    
    @State private var session = AVCaptureSession()
    @State private var output = AVCaptureMovieFileOutput()
    @State private var recorderDelegate: RecorderDelegate?
    @State private var isRecording = false
    @State private var didStartInitialRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var cameraPosition: AVCaptureDevice.Position = .front
    @State private var opacity: CGFloat = 0 // Анимация появления
    
    private let maxRecordingDuration: TimeInterval = 60.0
    private let lockThreshold = -70.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 28) {
                    Text(formattedTime)
                        .font(.compound.bodySMSemibold)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.45), in: Capsule())
                    
                    Spacer()
                }
                .padding(.top, 24)
                
                videoPreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
                VStack(spacing: 14) {
                    if !isLocked {
                        CompoundIcon(\.lockSolid, size: .small, relativeTo: .compound.bodyMD)
                            .foregroundStyle(.compound.iconPrimary)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    
                    HStack(spacing: 24) {
                        Button(action: cancelRecording) {
                            CompoundIcon(\.delete, size: .medium, relativeTo: .compound.headingLG)
                                .foregroundStyle(.compound.iconPrimary)
                                .padding(14)
                                .background(Color.compound.bgSubtleSecondary, in: Circle())
                        }
                        
                        recordControl
                        
                        Button(action: switchCamera) {
                            Image(systemName: "camera.rotate")
                                .font(.title2)
                                .foregroundStyle(.compound.iconPrimary)
                                .padding(14)
                                .background(Color.compound.bgSubtleSecondary, in: Circle())
                        }
                    }
                }
                .padding(.bottom, max(geometry.safeAreaInsets.bottom + 24, 32))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .opacity(opacity) // Анимация появления
        .onAppear {
            setup()
            DispatchQueue.main.async {
                handleCommand(command)
            }
            // Добавляем анимацию появления
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1
            }
        }
        .onChange(of: command) { _, newValue in
            handleCommand(newValue)
        }
        .onDisappear { cleanup() }
    }
    
    private func setup() {
        guard !session.isRunning else {
            startRecordingIfNeeded()
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: cameraPosition),
            let input = try? AVCaptureDeviceInput(device: device) else { return }

        // Configure camera for 1:1 aspect ratio
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = 1.0

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            device.unlockForConfiguration()
        } catch {
            MXLog.error("Failed to configure camera: \(error)")
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(output) {
            session.addOutput(output)

            // Configure output for 1:1 aspect ratio
            if let connection = output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = cameraPosition == .front
                }
            }
        }

        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        startRecordingIfNeeded()
    }

    private var videoPreview: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 280, height: 280)

            CameraPreview(session: session)
                .clipShape(Circle())
                .frame(width: 260, height: 260)
                .aspectRatio(1, contentMode: .fill)

            Circle()
                .trim(from: 0, to: min(recordingTime / maxRecordingDuration, 1))
                .stroke(Color.red, style: .init(lineWidth: 6, lineCap: .round))
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: recordingTime)
        }
    }
    
    private func startRecordingIfNeeded() {
        guard !didStartInitialRecording else {
            return
        }
        
        didStartInitialRecording = true
        DispatchQueue.main.async {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !output.isRecording else {
            return
        }

        isRecording = true
        recordingTime = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= maxRecordingDuration {
                stopRecording()
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mov")

        // Configure output for 1:1 aspect ratio
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = cameraPosition == .front
            }

            // Set max recorded duration to 60 seconds
            output.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 1)
        }
        
        let delegate = RecorderDelegate { recordedURL in
            DispatchQueue.main.async {
                isRecording = false
                onFinish(recordedURL)
            }
        }
        recorderDelegate = delegate
        output.startRecording(to: url, recordingDelegate: delegate)
    }
    
    private func stopRecording() {
        guard output.isRecording else {
            return
        }
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        output.stopRecording()
    }
    
    private func cancelRecording() {
        recorderDelegate?.shouldDeliverCompletion = false
        cleanup()
        onCancel()
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil

        if output.isRecording {
            output.stopRecording()
        }

        isRecording = false

        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }
    
    private func switchCamera() {
        cameraPosition = cameraPosition == .front ? .back : .front
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        for input in session.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput,
               deviceInput.device.hasMediaType(.video) {
                session.removeInput(deviceInput)
            }
        }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: cameraPosition),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input) else {
            return
        }
        
        session.addInput(input)
    }
    
    private func handleCommand(_ command: RoomRecordingOverlayController.VideoRecorderCommand?) {
        switch command?.kind {
        case .start, .none:
            break
        case .finish:
            stopRecording()
        case .cancel:
            cancelRecording()
        }
    }
    
    @ViewBuilder
    private var recordControl: some View {
        if isLocked {
            SendButton {
                stopRecording()
            }
        } else {
            Circle()
                .fill(Color.red)
                .frame(width: 78, height: 78)
                .overlay {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard value.translation.height <= lockThreshold else {
                            return
                        }
                            
                        onLock()
                    })
                .onTapGesture {
                    stopRecording()
                }
        }
    }
    
    private var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

final class RecorderDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var shouldDeliverCompletion = true
    let completion: (URL) -> Void
    
    init(completion: @escaping (URL) -> Void) {
        self.completion = completion
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        guard error == nil, shouldDeliverCompletion else {
            return
        }
        
        completion(outputFileURL)
    }
}
