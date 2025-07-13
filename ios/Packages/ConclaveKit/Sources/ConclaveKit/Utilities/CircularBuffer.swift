import Foundation

/// A high-performance circular buffer implementation for managing bounded collections
/// Automatically overwrites old items when capacity is exceeded
public struct CircularBuffer<Element> {
    private var storage: [Element?]
    private var head: Int = 0
    private var tail: Int = 0
    private var _count: Int = 0

    public let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be greater than 0")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public var count: Int {
        return _count
    }

    public var isEmpty: Bool {
        return _count == 0
    }

    public var isFull: Bool {
        return _count == capacity
    }

    public mutating func append(_ element: Element) {
        storage[tail] = element
        tail = (tail + 1) % capacity

        if _count == capacity {
            // Buffer is full, overwrite the oldest element
            head = (head + 1) % capacity
        } else {
            _count += 1
        }
    }

    public mutating func removeFirst() -> Element? {
        guard !isEmpty else { return nil }

        let element = storage[head]
        storage[head] = nil
        head = (head + 1) % capacity
        _count -= 1

        return element
    }

    public mutating func removeLast() -> Element? {
        guard !isEmpty else { return nil }

        tail = (tail - 1 + capacity) % capacity
        let element = storage[tail]
        storage[tail] = nil
        _count -= 1

        return element
    }

    public func first() -> Element? {
        guard !isEmpty else { return nil }
        return storage[head]
    }

    public func last() -> Element? {
        guard !isEmpty else { return nil }
        let lastIndex = (tail - 1 + capacity) % capacity
        return storage[lastIndex]
    }

    public mutating func removeAll() {
        head = 0
        tail = 0
        _count = 0
        storage = Array(repeating: nil, count: capacity)
    }

    // Get the most recent N elements (useful for getting recent messages)
    public func recent(_ n: Int) -> [Element] {
        let requestedCount = Swift.min(n, _count)
        guard requestedCount > 0 else { return [] }

        var result: [Element] = []
        result.reserveCapacity(requestedCount)

        var index = (tail - requestedCount + capacity) % capacity
        for _ in 0..<requestedCount {
            if let element = storage[index] {
                result.append(element)
            }
            index = (index + 1) % capacity
        }

        return result
    }
}

// MARK: - Sequence Conformance

extension CircularBuffer: Sequence {
    public func makeIterator() -> Iterator {
        return Iterator(buffer: self)
    }

    public struct Iterator: IteratorProtocol {
        private let buffer: CircularBuffer<Element>
        private var currentIndex: Int
        private var itemsReturned: Int = 0

        fileprivate init(buffer: CircularBuffer<Element>) {
            self.buffer = buffer
            self.currentIndex = buffer.head
        }

        public mutating func next() -> Element? {
            guard itemsReturned < buffer.count else { return nil }

            let element = buffer.storage[currentIndex]
            currentIndex = (currentIndex + 1) % buffer.capacity
            itemsReturned += 1

            return element
        }
    }
}

// MARK: - Collection Conformance

extension CircularBuffer: Collection {
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return _count }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < _count, "Index out of bounds")
        let actualIndex = (head + position) % capacity
        return storage[actualIndex]!
    }
}

// MARK: - Thread-Safe Wrapper

/// A thread-safe wrapper around CircularBuffer
/// Uses a concurrent queue with proper barrier synchronization for optimal performance.
/// @unchecked Sendable is safe here because:
/// 1. All reads use concurrent access (safe for immutable operations)
/// 2. All writes use barrier flags to ensure exclusive access during mutations
/// 3. Element is constrained to Sendable
/// 4. The concurrent queue with barriers provides proper read-write synchronization
public final class SynchronizedCircularBuffer<Element: Sendable>: @unchecked
    Sendable
{
    private var _buffer: CircularBuffer<Element>
    private let queue = DispatchQueue(
        label: "com.conclave.circular-buffer",
        attributes: .concurrent
    )

    public init(capacity: Int) {
        self._buffer = CircularBuffer(capacity: capacity)
    }

    // Read operations - can be concurrent
    public var count: Int {
        return queue.sync { _buffer.count }
    }

    public var isEmpty: Bool {
        return queue.sync { _buffer.isEmpty }
    }

    public var isFull: Bool {
        return queue.sync { _buffer.isFull }
    }

    public func recent(_ n: Int) -> [Element] {
        return queue.sync { _buffer.recent(n) }
    }

    public func first() -> Element? {
        return queue.sync { _buffer.first() }
    }

    public func last() -> Element? {
        return queue.sync { _buffer.last() }
    }

    // Write operations - require exclusive access with barriers
    public func append(_ element: Element) {
        queue.async(flags: .barrier) {
            self._buffer.append(element)
        }
    }

    public func removeFirst() -> Element? {
        return queue.sync(flags: .barrier) { _buffer.removeFirst() }
    }

    public func removeLast() -> Element? {
        return queue.sync(flags: .barrier) { _buffer.removeLast() }
    }

    public func removeAll() {
        queue.async(flags: .barrier) {
            self._buffer.removeAll()
        }
    }
}
