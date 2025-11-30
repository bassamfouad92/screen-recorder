# Final Refactored Architecture

## Complete System Architecture

```mermaid
graph TB
    subgraph "UI Layer"
        View[RecordingScreenView<br/>SwiftUI]
        CameraView[CameraView<br/>SwiftUI]
        ControlPanel[ControlPanelView]
    end
    
    subgraph "Presentation Layer - Framework Independent"
        ViewModel[RecordingScreenViewModel<br/>✅ No Framework Imports<br/>Only Combine]
        
        subgraph "Protocols"
            CameraProtocol[CameraCaptureProvider<br/>Protocol]
            WindowProtocol[WindowContentProvider<br/>Protocol]
        end
        
        subgraph "Type Wrappers"
            WindowRef[WindowReference<br/>Type-Erased Wrapper]
        end
    end
    
    subgraph "Business Logic Layer"
        Manager[ScreenRecordManager<br/>Orchestrator]
        BufferAdj[BufferAdjuster<br/>Pause/Resume Logic]
        Config[RecordingConfiguration<br/>Value Object]
        Events[RecordingEvent<br/>ViewEvent]
    end
    
    subgraph "Service Layer - Real Implementations"
        CameraService[CameraCaptureService<br/>AVFoundation]
        WindowService[SCKWindowContentService<br/>ScreenCaptureKit]
        Pipeline[SCKScreenRecordingPipeline<br/>ScreenCaptureKit]
        Writer[SCKRecordingFileWriter<br/>AVFoundation]
        MicManager[MicrophoneCaptureManager<br/>AVAudioEngine]
    end
    
    subgraph "Test Layer"
        MockCamera[MockCameraCaptureProvider]
        MockWindow[MockWindowContentProvider]
    end
    
    subgraph "Model Layer"
        RecordingBuffer[RecordingBuffer<br/>Unified Buffer Type]
        WriterConfig[WriterConfig<br/>Configuration]
        FileManager[RecordFileManager<br/>File Operations]
    end
    
    subgraph "Utilities"
        DebugLogger[DebugLogger<br/>Structured Logging]
        Helpers[RecordingHelpers<br/>Utilities]
    end
    
    %% UI to ViewModel
    View -->|Actions| ViewModel
    View -->|Observes State| ViewModel
    CameraView -->|Uses| CameraProtocol
    ControlPanel -->|Sends Actions| ViewModel
    
    %% ViewModel Dependencies (Protocol Only)
    ViewModel -->|Depends on| CameraProtocol
    ViewModel -->|Depends on| WindowProtocol
    ViewModel -->|Uses| WindowRef
    ViewModel -->|Creates| Manager
    ViewModel -->|Emits| Events
    
    %% Protocol Implementations
    CameraProtocol -.->|Implemented by| CameraService
    CameraProtocol -.->|Mocked by| MockCamera
    WindowProtocol -.->|Implemented by| WindowService
    WindowProtocol -.->|Mocked by| MockWindow
    
    %% Manager Orchestration
    Manager -->|Uses| Config
    Manager -->|Creates| Pipeline
    Manager -->|Creates| Writer
    Manager -->|Uses| BufferAdj
    Manager -->|Converts| WindowRef
    Manager -->|Emits| Events
    
    %% Service Dependencies
    Pipeline -->|Captures Screen| WindowService
    Pipeline -->|Captures Audio| MicManager
    Pipeline -->|Emits| RecordingBuffer
    BufferAdj -->|Adjusts| RecordingBuffer
    BufferAdj -->|Filters when paused| RecordingBuffer
    Writer -->|Writes| RecordingBuffer
    Writer -->|Uses| WriterConfig
    Writer -->|Saves to| FileManager
    
    %% Logging
    ViewModel -.->|Logs| DebugLogger
    Manager -.->|Logs| DebugLogger
    Pipeline -.->|Logs| DebugLogger
    Writer -.->|Logs| DebugLogger
    
    %% Styling
    classDef uiLayer fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef viewModelLayer fill:#f3e5f5,stroke:#4a148c,stroke-width:3px
    classDef protocolLayer fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef serviceLayer fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef testLayer fill:#ffebee,stroke:#b71c1c,stroke-width:2px
    classDef modelLayer fill:#e0f2f1,stroke:#004d40,stroke-width:2px
    
    class View,CameraView,ControlPanel uiLayer
    class ViewModel viewModelLayer
    class CameraProtocol,WindowProtocol,WindowRef protocolLayer
    class CameraService,WindowService,Pipeline,Writer,MicManager serviceLayer
    class MockCamera,MockWindow testLayer
    class RecordingBuffer,WriterConfig,FileManager,Config,Events,BufferAdj modelLayer
```

## Data Flow Architecture

```mermaid
sequenceDiagram
    participant V as RecordingScreenView
    participant VM as RecordingScreenViewModel
    participant M as ScreenRecordManager
    participant BA as BufferAdjuster
    participant P as SCKScreenRecordingPipeline
    participant W as SCKRecordingFileWriter
    participant Mic as MicrophoneCaptureManager
    
    Note over V,Mic: Recording Start Flow
    
    V->>VM: startRecording()
    VM->>VM: setupWindows (via WindowContentProvider)
    VM->>VM: isReadyToStart = true
    V->>VM: Observes isReadyToStart
    V->>VM: startRecording()
    
    VM->>M: record(displayID, windows...)
    M->>M: Convert WindowReference → SCWindow
    M->>P: Initialize Pipeline
    M->>W: Initialize Writer
    M->>Mic: Start if recordMic enabled
    
    Note over P,Mic: Recording In Progress
    
    P->>P: Capture Screen Frames
    P->>P: Capture App Audio
    Mic->>P: Emit Mic Buffers
    P->>P: Unify as RecordingBuffer
    P->>M: processedBuffers.send
    M->>BA: adjust(buffer)
    BA->>M: Return adjusted buffer
    M->>W: write(adjusted)
    W->>W: Write Video/Audio
    
    Note over V,W: User Actions - Pause
    
    V->>VM: sendAction(.pause)
    VM->>M: actionInput.send(.pause)
    M->>P: actionInput.send(.pause)
    M->>BA: pause()
    BA->>BA: isPaused = true
    P->>M: processedBuffers.send
    M->>BA: adjust(buffer)
    BA->>M: Return nil
    Note over M: compactMap drops nil
    Note over W: Writer NOT called
    
    Note over V,W: User Actions - Resume
    
    V->>VM: sendAction(.resume)
    VM->>M: actionInput.send(.resume)
    M->>P: actionInput.send(.resume)
    M->>BA: resume()
    BA->>BA: isPaused = false
    P->>M: processedBuffers.send
    M->>BA: adjust(buffer)
    BA->>BA: Calculate pause duration<br/>Adjust PTS
    BA->>M: Return adjusted buffer
    M->>W: write(adjusted)
    
    Note over V,W: Recording Stop
    
    V->>VM: sendAction(.stop)
    VM->>M: actionInput.send(.stop)
    M->>P: actionInput.send(.stop)
    M->>W: finish()
    W-->>M: Return URL
    M-->>VM: events.send(.stopped(URL))
    VM-->>V: recordingState = .stopped
```

## Dependency Injection Architecture

```mermaid
graph LR
    subgraph "Testable ViewModel"
        VM[RecordingScreenViewModel]
    end
    
    subgraph "Protocol Dependencies"
        CP[CameraCaptureProvider]
        WP[WindowContentProvider]
    end
    
    subgraph "Production Implementations"
        CS[CameraCaptureService]
        WS[SCKWindowContentService]
    end
    
    subgraph "Test Implementations"
        MC[MockCameraCaptureProvider]
        MW[MockWindowContentProvider]
    end
    
    VM -->|Depends on| CP
    VM -->|Depends on| WP
    
    CP -.->|Production| CS
    CP -.->|Testing| MC
    
    WP -.->|Production| WS
    WP -.->|Testing| MW
    
    style VM fill:#f3e5f5,stroke:#4a148c,stroke-width:3px
    style CP fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    style WP fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    style CS fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    style WS fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    style MC fill:#ffebee,stroke:#b71c1c,stroke-width:2px
    style MW fill:#ffebee,stroke:#b71c1c,stroke-width:2px
```

```

## Pause/Resume Flow Architecture

```mermaid
sequenceDiagram
    participant V as RecordingScreenView
    participant VM as RecordingScreenViewModel
    participant M as ScreenRecordManager
    participant BA as BufferAdjuster
    participant P as SCKScreenRecordingPipeline
    participant W as SCKRecordingFileWriter
    
    Note over V,W: Pause Flow
    
    V->>VM: sendAction(.pause)
    VM->>M: actionInput.send(.pause)
    M->>P: actionInput.send(.pause)
    Note over P: Logs pause (no state change)
    M->>BA: pause()
    BA->>BA: isPaused = true<br/>pauseStartPTS = nil
    
    Note over P,W: Buffers Continue Flowing
    
    P->>M: processedBuffers.send(buffer)
    M->>BA: adjust(buffer)
    BA->>BA: Mark pauseStartPTS<br/>Return nil
    Note over M: compactMap drops nil
    Note over W: Writer NOT called
    
    Note over V,W: Resume Flow
    
    V->>VM: sendAction(.resume)
    VM->>M: actionInput.send(.resume)
    M->>P: actionInput.send(.resume)
    Note over P: Logs resume (no state change)
    M->>BA: resume()
    BA->>BA: isPaused = false<br/>totalPauseDuration = .zero
    
    Note over P,W: Buffers Resume Processing
    
    P->>M: processedBuffers.send(buffer)
    M->>BA: adjust(buffer)
    BA->>BA: Calculate pause duration<br/>Adjust PTS<br/>Return adjusted buffer
    M->>W: write(adjusted)
    W->>W: Append to file
```

## Buffer Flow Architecture with Pause/Resume

```mermaid
graph TB
    subgraph "Capture Sources"
        Screen[Screen Capture<br/>ScreenCaptureKit]
        AppAudio[App Audio<br/>ScreenCaptureKit]
        Mic[Microphone<br/>AVAudioEngine]
    end
    
    subgraph "Pipeline Processing"
        Pipeline[SCKScreenRecordingPipeline<br/>Always Streaming]
        
        subgraph "Buffer Unification"
            VideoBuffer[RecordingBuffer<br/>.video]
            AppAudioBuffer[RecordingBuffer<br/>.appAudio]
            MicBuffer[RecordingBuffer<br/>.microphone]
        end
    end
    
    subgraph "Manager Processing"
        Manager[ScreenRecordManager]
        BufferAdjuster[BufferAdjuster<br/>Pause/Resume Logic]
        
        subgraph "Combine Pipeline"
            CompactMap[compactMap<br/>Drops nil when paused]
            Sink[sink<br/>Writes to file]
        end
    end
    
    subgraph "Writer Processing"
        Writer[SCKRecordingFileWriter<br/>Dumb Writer]
        
        subgraph "Writer Inputs"
            VideoInput[AVAssetWriterInput<br/>Video]
            AppAudioInput[AVAssetWriterInput<br/>App Audio]
            MicAudioInput[AVAssetWriterInput<br/>Mic Audio]
        end
    end
    
    subgraph "Output"
        File[MP4/MOV File]
    end
    
    Screen -->|CMSampleBuffer| Pipeline
    AppAudio -->|CMSampleBuffer| Pipeline
    Mic -->|CMSampleBuffer| Pipeline
    
    Pipeline -->|Emit| VideoBuffer
    Pipeline -->|Emit| AppAudioBuffer
    Pipeline -->|Emit| MicBuffer
    
    VideoBuffer -->|processedBuffers| Manager
    AppAudioBuffer -->|processedBuffers| Manager
    MicBuffer -->|processedBuffers| Manager
    
    Manager -->|buffer| BufferAdjuster
    BufferAdjuster -->|adjusted or nil| CompactMap
    CompactMap -->|adjusted only| Sink
    Sink -->|write| Writer
    
    Writer -->|Route to| VideoInput
    Writer -->|Route to| AppAudioInput
    Writer -->|Route to| MicAudioInput
    
    VideoInput -->|Write| File
    AppAudioInput -->|Write| File
    MicAudioInput -->|Write| File
    
    style Pipeline fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    style BufferAdjuster fill:#fff9c4,stroke:#f57f17,stroke-width:3px
    style Writer fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    style VideoBuffer fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    style AppAudioBuffer fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    style MicBuffer fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    style CompactMap fill:#fff3e0,stroke:#e65100,stroke-width:2px
```

## Layer Responsibilities

### 🎨 UI Layer
- **RecordingScreenView**: SwiftUI view, handles UI events, observes ViewModel
- **CameraView**: Camera preview with presentation styles
- **ControlPanelView**: Recording controls (play/pause/stop/restart/delete)

### 🧠 Presentation Layer (Framework-Independent)
- **RecordingScreenViewModel**: 
  - ✅ NO framework imports (only Combine)
  - Manages UI state
  - Coordinates services via protocols
  - Emits view events
  - 100% testable

### 🔌 Protocols
- **CameraCaptureProvider**: Camera abstraction
- **WindowContentProvider**: Window lookup abstraction
- **ScreenRecordingPipeline**: Recording pipeline abstraction
- **RecordingFileWriter**: File writing abstraction

### 🎬 Business Logic Layer
- **ScreenRecordManager**: Orchestrates recording workflow
- **RecordingConfiguration**: Immutable configuration
- **RecordingEvent/ViewEvent**: Event types

### ⚙️ Service Layer
- **SCKScreenRecordingPipeline**: Screen/audio capture using ScreenCaptureKit (always streaming)
- **SCKRecordingFileWriter**: File writing using AVFoundation (dumb writer, no pause logic)
- **BufferAdjuster**: Handles pause/resume timestamp adjustments using Combine operators
- **CameraCaptureService**: Camera capture using AVFoundation
- **SCKWindowContentService**: Window management using ScreenCaptureKit
- **MicrophoneCaptureManager**: Microphone capture using AVAudioEngine

### 🧪 Test Layer
- **MockCameraCaptureProvider**: Camera mock for testing
- **MockWindowContentProvider**: Window mock for testing

### 📦 Model Layer
- **RecordingBuffer**: Unified buffer wrapper with `adjusted(with:)` method
- **WindowReference**: Type-erased window wrapper
- **WriterConfig**: Writer configuration
- **RecordFileManager**: File management

### 🛠️ Utilities
- **DebugLogger**: Structured, categorized logging
- **RecordingHelpers**: Helper functions
- **CMSampleBuffer+retimed**: Extension for timestamp adjustment

## Key Design Patterns

1. **Dependency Injection**: All dependencies injected via init
2. **Protocol-Oriented**: ViewModel depends on protocols only
3. **Type Erasure**: `WindowReference` hides `SCWindow` from ViewModel
4. **Publisher/Subscriber**: Combine for reactive data flow
5. **Orchestrator**: `ScreenRecordManager` coordinates components
6. **Factory Method**: `WriterConfig.create()` for complex configuration
7. **Strategy Pattern**: Different recording modes (fullscreen/window/camera)
8. **Functional Reactive**: Combine operators (`compactMap`, `sink`) for pause/resume logic

## Pause/Resume Architecture

### Design Philosophy
The pause/resume functionality is implemented using **functional reactive programming** with Combine operators, separating concerns cleanly:

- **Pipeline**: Dumb streamer - always captures and emits buffers
- **BufferAdjuster**: Smart filter - decides what to pass through and adjusts timestamps
- **Writer**: Dumb writer - writes whatever it receives

### Implementation Details

```swift
// In ScreenRecordManager
pipeline.processedBuffers
    .compactMap { [weak self] buffer in
        self?.bufferAdjuster.adjust(buffer)  // Returns nil when paused
    }
    .sink { [weak writer] adjusted in
        writer?.write(adjusted)  // Only called when not paused
    }
    .store(in: &cancellables)
```

### BufferAdjuster Logic

1. **Pause**:
   - Set `isPaused = true`
   - Mark `pauseStartPTS` on first paused buffer
   - Return `nil` for all buffers (dropped by `compactMap`)

2. **Resume**:
   - Set `isPaused = false`
   - Reset `totalPauseDuration = .zero`
   - Calculate pause duration from first resumed buffer
   - Adjust PTS by subtracting total pause duration
   - Return adjusted buffer

3. **Benefits**:
   - ✅ No state management in Pipeline or Writer
   - ✅ Buffers continue flowing (no startup latency on resume)
   - ✅ Timestamp continuity maintained in output file
   - ✅ Testable in isolation
   - ✅ Declarative Combine pipeline

## Benefits Achieved

✅ **100% Testable ViewModel** - No framework dependencies  
✅ **Clean Architecture** - Clear layer separation  
✅ **SOLID Principles** - All 5 principles followed  
✅ **Reactive** - Combine-based data flow  
✅ **Maintainable** - Single responsibility per component  
✅ **Flexible** - Easy to swap implementations  
✅ **Observable** - Comprehensive debug logging  
✅ **Type-Safe** - Protocol-based contracts  
