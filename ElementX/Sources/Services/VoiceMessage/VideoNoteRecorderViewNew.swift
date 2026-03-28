//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import SwiftUI

struct VideoNoteRecorderViewNew: View {
    var onFinish: (URL) -> Void
    var onCancel: () -> Void
    
    @State private var session = AVCaptureSession()
    @State private var output = AVCaptureMovieFileOutput()
    @State private var recorderDelegate: RecorderDelegateNew?
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isUsingFrontCamera = true
    
    private let maxRecordingDuration: TimeInterval = 60.0
    
    var body: some View {
        ZStack {
            // Полупрозрачный фон
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Кружок с камерой
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 200, height: 200)
                        .overlay(Circle()
                            .stroke(Color.white, lineWidth: 3))
                    
                    CameraPreview(session: session)
                        .clipShape(Circle())
                        .frame(width: 190, height: 190)
                    
                    // Таймлайн вокруг кружка
                    if isRecording {
                        Circle()
                            .trim(from: 0, to: CGFloat(recordingTime / maxRecordingDuration))
                            .stroke(Color.red, lineWidth: 4)
                            .frame(width: 210, height: 210)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: recordingTime)
                    }
                    
                    // Таймер в центре
                    if isRecording {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatTime(recordingTime))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(width: 190, height: 190)
                    }
                }
                
                Spacer()
                
                // Кнопки управления
                HStack(spacing: 60) {
                    // Кнопка отмены
                    Button(action: cancelRecording) {
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white))
                    }
                    
                    // Кнопка записи/остановки
                    Button(action: toggleRecording) {
                        Circle()
                            .fill(isRecording ? Color.red : Color.white)
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: isRecording ? "stop.fill" : "record.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(isRecording ? .white : .red))
                    }
                    
                    // Кнопка смены камеры
                    Button(action: switchCamera) {
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "camera.rotate")
                                .font(.title2)
                                .foregroundColor(.white))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear { setup() }
        .onDisappear { cleanup() }
    }
    
    private func setup() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        setupCamera()
        setupAudio()
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(isUsingFrontCamera ? .builtInWideAngleCamera : .builtInWideAngleCamera,
                                                   for: .video,
                                                   position: isUsingFrontCamera ? .front : .back),
            let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        // Удаляем существующий input если есть
        for currentInput in session.inputs {
            if let currentInput = currentInput as? AVCaptureDeviceInput {
                session.removeInput(currentInput)
            }
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
    }
    
    private func setupAudio() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }
        
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= maxRecordingDuration {
                stopRecording()
            }
        }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mov")
        
        let delegate = RecorderDelegateNew { recordedURL in
            DispatchQueue.main.async {
                onFinish(recordedURL)
            }
        }
        recorderDelegate = delegate
        output.startRecording(to: url, recordingDelegate: delegate)
    }
    
    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        output.stopRecording()
    }
    
    private func cancelRecording() {
        if isRecording {
            stopRecording()
        }
        cleanup()
        onCancel()
    }
    
    private func switchCamera() {
        isUsingFrontCamera.toggle()
        setupCamera()
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        session.stopRunning()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

final class RecorderDelegateNew: NSObject, AVCaptureFileOutputRecordingDelegate {
    let completion: (URL) -> Void
    
    init(completion: @escaping (URL) -> Void) {
        self.completion = completion
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        completion(outputFileURL)
    }
}
