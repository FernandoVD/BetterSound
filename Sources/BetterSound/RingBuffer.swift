import CoreAudio
import Darwin

/// Lightweight thread-safe float box for passing a gain value into a real-time
/// audio callback without allocating or taking a heavyweight lock.
final class AtomicFloat {
    private var lock = os_unfair_lock()
    private var _value: Float

    init(_ value: Float) { self._value = value }

    var value: Float {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return _value
        }
        set {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            _value = newValue
        }
    }
}

/// Moves interleaved Float32 audio between the tap's capture callback and the
/// output render callback, which run on independent device clocks/threads.
/// v1 assumes a single interleaved buffer (the common case for HAL device
/// streams); a non-interleaved (multi-buffer) tap format is a silent no-op.
final class RingBuffer {
    private var storage: [Float]
    private var writeIndex = 0
    private var readIndex = 0
    private var filled = 0
    private let capacity: Int
    private var lock = os_unfair_lock()

    init(capacityFrames: Int, channels: Int) {
        capacity = max(channels, capacityFrames * channels)
        storage = [Float](repeating: 0, count: capacity)
    }

    func write(from bufferList: UnsafePointer<AudioBufferList>, gain: Float) {
        let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
        guard abl.count == 1, let buffer = abl.first, let mData = buffer.mData else { return }
        let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        guard sampleCount > 0 else { return }
        let samples = mData.assumingMemoryBound(to: Float.self)

        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        for i in 0..<sampleCount {
            storage[writeIndex] = samples[i] * gain
            writeIndex = (writeIndex + 1) % capacity
        }
        filled = min(capacity, filled + sampleCount)
    }

    func read(into bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)
        guard abl.count == 1, let buffer = abl.first, let mData = buffer.mData else { return }
        let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        guard sampleCount > 0 else { return }
        let out = mData.assumingMemoryBound(to: Float.self)

        os_unfair_lock_lock(&lock)
        let available = min(sampleCount, filled)
        for i in 0..<available {
            out[i] = storage[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        filled -= available
        os_unfair_lock_unlock(&lock)

        // Silence out any frames we couldn't fill (underrun).
        if available < sampleCount {
            for i in available..<sampleCount { out[i] = 0 }
        }
    }
}
