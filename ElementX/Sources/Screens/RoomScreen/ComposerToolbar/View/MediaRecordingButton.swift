//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

enum MediaRecordingMode: Equatable {
    case voice
    case video
    
    var icon: KeyPath<CompoundIcons, Image> {
        switch self {
        case .voice:
            return \.micOn
        case .video:
            return \.videoCallSolid
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .voice:
            return L10n.a11yVoiceMessageRecord
        case .video:
            return "Record video message"
        }
    }
}

struct MediaRecordingButton: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isLongPressing = false
    @State private var activeRecordingMode: MediaRecordingMode?
    @State private var startRecordingWorkItem: DispatchWorkItem?
    @State private var didLockRecording = false
    @State private var lockDragProgress: CGFloat = 0
    
    @Binding var currentMode: MediaRecordingMode
    
    let onStartRecording: (MediaRecordingMode) -> Void
    let onLockRecording: (MediaRecordingMode) -> Void
    let onRecordingDragChanged: (MediaRecordingMode, CGFloat) -> Void
    let onStopRecording: (MediaRecordingMode) -> Void
    
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator()
    private let rigidFeedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let longPressDuration = 0.3
    private let lockThreshold = -70.0
    
    var body: some View {
        ZStack {
            if currentMode == .voice {
                recordingModeIcon(for: .voice)
                    .transition(.asymmetric(insertion: .scale(scale: 0.88).combined(with: .opacity),
                                            removal: .opacity))
            } else {
                recordingModeIcon(for: .video)
                    .transition(.asymmetric(insertion: .scale(scale: 0.88).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .foregroundColor(isEnabled ? .compound.iconSecondary : .compound.iconDisabled)
        .scaledPadding(10, relativeTo: .compound.headingLG)
        .opacity(isLongPressing ? 0.6 : 1)
        .scaleEffect(isLongPressing ? 1.08 : 1.0)
        .offset(y: isLongPressing ? -4.0 * lockDragProgress : 0)
        .animation(.spring(response: 0.26, dampingFraction: 0.82).disabledDuringTests(), value: isLongPressing)
        .animation(.easeInOut(duration: 0.18).disabledDuringTests(), value: currentMode)
        .animation(.easeOut(duration: 0.12).disabledDuringTests(), value: lockDragProgress)
        .contentShape(Circle())
        .gesture(recordingGesture)
        .accessibilityLabel(currentMode.accessibilityLabel)
    }
    
    private func recordingModeIcon(for mode: MediaRecordingMode) -> some View {
        CompoundIcon(mode.icon, size: .medium, relativeTo: .compound.headingLG)
    }
    
    private func toggleMode() {
        currentMode = currentMode == .voice ? .video : .voice
    }
    
    private var recordingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isEnabled, startRecordingWorkItem == nil, activeRecordingMode == nil {
                    let workItem = DispatchWorkItem {
                        beginRecording()
                    }
                    startRecordingWorkItem = workItem
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration, execute: workItem)
                }
                
                guard let activeRecordingMode,
                      !didLockRecording,
                      value.translation.height <= 0 else {
                    if let activeRecordingMode {
                        lockDragProgress = 0
                        onRecordingDragChanged(activeRecordingMode, 0)
                    }
                    return
                }
                
                let progress = min(max(abs(value.translation.height) / abs(lockThreshold), 0), 1)
                lockDragProgress = progress
                onRecordingDragChanged(activeRecordingMode, progress)
                
                guard value.translation.height <= lockThreshold else {
                    return
                }
                
                didLockRecording = true
                rigidFeedbackGenerator.impactOccurred()
                onLockRecording(activeRecordingMode)
            }
            .onEnded { _ in
                endInteraction()
            }
    }
    
    private func beginRecording() {
        guard isEnabled, activeRecordingMode == nil else {
            return
        }
        
        let mode = currentMode
        activeRecordingMode = mode
        didLockRecording = false
        lockDragProgress = 0
        withElementAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
            isLongPressing = true
        }
        impactFeedbackGenerator.impactOccurred()
        onStartRecording(mode)
    }
    
    private func endInteraction() {
        startRecordingWorkItem?.cancel()
        startRecordingWorkItem = nil
        
        if let mode = activeRecordingMode {
            activeRecordingMode = nil
            lockDragProgress = 0
            onRecordingDragChanged(mode, 0)
            withElementAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                isLongPressing = false
            }
            defer { didLockRecording = false }
            onStopRecording(mode)
        } else if isEnabled {
            impactFeedbackGenerator.impactOccurred()
            toggleMode()
        }
    }
}

struct MediaRecordingButton_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("Media Recording Button")
    }
}

private struct PreviewWrapper: View {
    @State private var mode: MediaRecordingMode = .voice
    
    var body: some View {
        HStack(spacing: 16) {
            MediaRecordingButton(currentMode: $mode,
                                 onStartRecording: { _ in },
                                 onLockRecording: { _ in },
                                 onRecordingDragChanged: { _, _ in },
                                 onStopRecording: { _ in })
        }
    }
}
