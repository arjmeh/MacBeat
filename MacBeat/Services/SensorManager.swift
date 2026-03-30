import Combine
import Foundation
import IOKit
import IOKit.hid
import QuartzCore
import simd

final class SensorManager: ObservableObject {
    @Published private(set) var connectionState: SensorConnectionState = .disconnected
    @Published private(set) var connectionMessage = "Waiting for AppleSPUHIDDevice."
    @Published private(set) var latestSample: AccelSample = .zero
    @Published private(set) var recentMagnitudes: [Double] = Array(repeating: 0, count: 96)
    @Published private(set) var lastHit: HitEvent?

    var onHit: ((HitEvent) -> Void)?

    var sensitivity: Double = 0.72
    var cooldown: Double = 0.12

    private let reportLength = 22
    private let callbackBufferSize = 4096
    private let reportIntervalMicroseconds: Int32 = 1000
    private let publishStride = 4
    private var publishCounter = 0

    private var hidDevice: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>
    private var sensorThread: Thread?
    private var sensorRunLoop: CFRunLoop?

    private var detector = SlapDetector()
    private var waveformWindow: [Double] = Array(repeating: 0, count: 96)

    init() {
        reportBuffer = .allocate(capacity: callbackBufferSize)
        reportBuffer.initialize(repeating: 0, count: callbackBufferSize)
    }

    deinit {
        stop()
        reportBuffer.deinitialize(count: callbackBufferSize)
        reportBuffer.deallocate()
    }

    func start() {
        guard sensorThread == nil else { return }
        updateConnection(.searching, "Scanning for AppleSPUHIDDevice (usage page 0xFF00, usage 0x03).")

        let thread = Thread { [weak self] in
            self?.runSensorLoop()
        }
        thread.name = "MacBeat.SensorThread"
        thread.qualityOfService = .userInteractive
        sensorThread = thread
        thread.start()
    }

    func stop() {
        guard let runLoop = sensorRunLoop else {
            sensorThread = nil
            return
        }

        let runLoopMode = CFRunLoopMode.defaultMode.rawValue as CFString

        CFRunLoopPerformBlock(runLoop, runLoopMode) { [weak self] in
            guard let self else { return }
            if let hidDevice = self.hidDevice {
                IOHIDDeviceUnscheduleFromRunLoop(hidDevice, runLoop, runLoopMode)
                IOHIDDeviceClose(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
                self.hidDevice = nil
            }
            CFRunLoopStop(runLoop)
        }
        CFRunLoopWakeUp(runLoop)
        sensorRunLoop = nil
        sensorThread = nil
        updateConnection(.disconnected, "Sensor monitoring stopped.")
    }

    private func runSensorLoop() {
        guard let runLoop = CFRunLoopGetCurrent() else {
            updateConnection(.failed, "Sensor thread could not create a run loop.")
            sensorThread = nil
            return
        }
        sensorRunLoop = runLoop
        wakeAccelerometerDrivers()

        guard let device = findAccelerometerDevice() else {
            updateConnection(.unsupported, "No compatible Apple Silicon laptop accelerometer was found.")
            sensorRunLoop = nil
            sensorThread = nil
            return
        }

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            hidDevice = nil
            updateConnection(.failed, "Could not open AppleSPUHIDDevice. Build from Xcode with App Sandbox disabled.")
            sensorRunLoop = nil
            sensorThread = nil
            return
        }

        hidDevice = device
        let context = Unmanaged.passUnretained(self).toOpaque()
        let runLoopMode = CFRunLoopMode.defaultMode.rawValue as CFString
        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            callbackBufferSize,
            sensorReportCallback,
            context
        )
        IOHIDDeviceScheduleWithRunLoop(device, runLoop, runLoopMode)
        updateConnection(.connected, "Accelerometer live. Tuned for finger taps and desk drumming.")
        CFRunLoopRun()
    }

    private func wakeAccelerometerDrivers() {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else { return }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return }

        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 {
                break
            }

            defer { IOObjectRelease(service) }

            let usagePage = intProperty(service: service, key: "PrimaryUsagePage")
            let usage = intProperty(service: service, key: "PrimaryUsage")
            guard usagePage == 0xFF00, usage == 0x03 else { continue }

            _ = setIntProperty(service: service, key: "ReportInterval", value: reportIntervalMicroseconds)
            _ = setIntProperty(service: service, key: "SensorPropertyPowerState", value: 1)
            _ = setIntProperty(service: service, key: "SensorPropertyReportingState", value: 1)
        }
    }

    private func findAccelerometerDevice() -> IOHIDDevice? {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else {
            return nil
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 {
                return nil
            }

            defer { IOObjectRelease(service) }

            let usagePage = intProperty(service: service, key: "PrimaryUsagePage")
            let usage = intProperty(service: service, key: "PrimaryUsage")

            guard usagePage == 0xFF00, usage == 0x03 else { continue }

            let device = IOHIDDeviceCreate(kCFAllocatorDefault, service)
            if let device {
                return device
            }
        }
    }

    private func intProperty(service: io_registry_entry_t, key: String) -> Int? {
        guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }

        if let number = property as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func setIntProperty(service: io_registry_entry_t, key: String, value: Int32) -> Bool {
        var rawValue = value
        guard let number = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &rawValue) else {
            return false
        }
        return IORegistryEntrySetCFProperty(service, key as CFString, number) == KERN_SUCCESS
    }

    fileprivate func handleReport(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard length >= reportLength else { return }

        let timestamp = CACurrentMediaTime()
        let x = Double(parseInt32LE(report, offset: 6)) / 65536.0
        let y = Double(parseInt32LE(report, offset: 10)) / 65536.0
        let z = Double(parseInt32LE(report, offset: 14)) / 65536.0

        if let hit = detector.ingest(
            x: x,
            y: y,
            z: z,
            timestamp: timestamp,
            sensitivity: sensitivity,
            cooldown: cooldown
        ) {
            DispatchQueue.main.async { [weak self] in
                self?.lastHit = hit
                self?.onHit?(hit)
            }
        }

        let sample = AccelSample(
            x: detector.filteredVector.x,
            y: detector.filteredVector.y,
            z: detector.filteredVector.z,
            dynamicMagnitude: detector.currentMagnitude,
            timestamp: timestamp
        )

        waveformWindow.append(sample.dynamicMagnitude)
        if waveformWindow.count > 96 {
            waveformWindow.removeFirst(waveformWindow.count - 96)
        }

        publishCounter += 1
        guard publishCounter >= publishStride else { return }
        publishCounter = 0

        DispatchQueue.main.async { [weak self] in
            self?.latestSample = sample
            self?.recentMagnitudes = self?.waveformWindow ?? []
        }
    }

    private func parseInt32LE(_ report: UnsafeMutablePointer<UInt8>, offset: Int) -> Int32 {
        let a = UInt32(report[offset])
        let b = UInt32(report[offset + 1]) << 8
        let c = UInt32(report[offset + 2]) << 16
        let d = UInt32(report[offset + 3]) << 24
        return Int32(bitPattern: a | b | c | d)
    }

    private func updateConnection(_ state: SensorConnectionState, _ message: String) {
        DispatchQueue.main.async {
            self.connectionState = state
            self.connectionMessage = message
        }
    }
}

private func sensorReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard result == kIOReturnSuccess, let context else { return }
    let manager = Unmanaged<SensorManager>.fromOpaque(context).takeUnretainedValue()
    manager.handleReport(report: report, length: reportLength)
}

private struct SlapDetector {
    private let highPassAlpha = 0.93
    private let baselineWindowSize = 72

    private(set) var filteredVector = SIMD3<Double>(repeating: 0)
    private(set) var currentMagnitude = 0.0

    private var previousRaw = SIMD3<Double>(repeating: 0)
    private var ready = false
    private var baseline: [Double] = []
    private var lastHitTime = 0.0
    private var lastMagnitude = 0.0
    private var smoothedMagnitude = 0.0
    private var warmupSamples = 0

    mutating func ingest(
        x: Double,
        y: Double,
        z: Double,
        timestamp: Double,
        sensitivity: Double,
        cooldown: Double
    ) -> HitEvent? {
        let raw = SIMD3(x, y, z)

        guard ready else {
            previousRaw = raw
            ready = true
            return nil
        }

        filteredVector = highPassAlpha * (filteredVector + raw - previousRaw)
        previousRaw = raw
        currentMagnitude = simd_length(filteredVector)
        smoothedMagnitude = (smoothedMagnitude * 0.72) + (currentMagnitude * 0.28)
        warmupSamples += 1

        baseline.append(currentMagnitude)
        if baseline.count > baselineWindowSize {
            baseline.removeFirst(baseline.count - baselineWindowSize)
        }
        guard baseline.count >= 24, warmupSamples >= 40 else {
            lastMagnitude = currentMagnitude
            return nil
        }

        let median = baseline.median()
        let madSigma = max(baseline.mad(around: median) * 1.4826, 0.0001)
        let zScore = max(0, (currentMagnitude - median) / madSigma)
        let delta = currentMagnitude - lastMagnitude
        lastMagnitude = currentMagnitude

        let threshold = 3.8 - (sensitivity * 2.0)
        let transientFloor = max(0.010, median * 1.8)
        let deltaFloor = max(0.004, madSigma * 0.9)
        guard currentMagnitude > transientFloor else { return nil }
        guard zScore >= threshold, delta > deltaFloor else { return nil }
        guard timestamp - lastHitTime >= cooldown else { return nil }

        lastHitTime = timestamp
        let region = dominantRegion(for: filteredVector)
        let confidence = min(1.0, max(0.25, (zScore / max(threshold, 0.001)) * 0.45))

        // Use the event's strength above the adaptive threshold instead of raw
        // magnitude alone, which tends to compress most desk taps into the same
        // low bucket and makes everything sound like a hat.
        let zStrength = max(0.0, (zScore - threshold) / max(threshold * 0.9, 0.8))
        let magnitudeStrength = max(0.0, (currentMagnitude - transientFloor) / max(transientFloor * 1.6, 0.006))
        let deltaStrength = max(0.0, (delta - deltaFloor) / max(deltaFloor * 2.2, 0.003))
        let compositeStrength = (zStrength * 0.55) + (magnitudeStrength * 0.30) + (deltaStrength * 0.15)
        let intensity = min(1.0, max(0.05, compositeStrength))

        return HitEvent(
            timestamp: timestamp,
            intensity: intensity,
            confidence: confidence,
            vector: filteredVector,
            region: region
        )
    }

    private func dominantRegion(for vector: SIMD3<Double>) -> ChassisRegion {
        let x = vector.x
        let y = vector.y
        let z = vector.z
        let absX = abs(x)
        let absY = abs(y)
        let absZ = abs(z)
        let magnitude = max(simd_length(vector), 0.0001)

        // Bias the spatial split toward "left of trackpad" vs "right of trackpad".
        // We only emit left/right when the horizontal axis is clearly dominant.
        let horizontalThreshold = max(0.0045, magnitude * 0.36)
        let horizontalDominance = absX > horizontalThreshold && absX > (absY * 1.15) && absX > (absZ * 0.95)
        if horizontalDominance {
            return x >= 0 ? .right : .left
        }

        if absY > absZ * 1.2, absY > magnitude * 0.34 {
            return y >= 0 ? .top : .bottom
        }
        return .center
    }
}

private extension Array where Element == Double {
    func median() -> Double {
        guard isEmpty == false else { return 0 }
        let sorted = self.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle] + sorted[middle - 1]) / 2
        }
        return sorted[middle]
    }

    func mad(around center: Double) -> Double {
        map { abs($0 - center) }.median()
    }
}
