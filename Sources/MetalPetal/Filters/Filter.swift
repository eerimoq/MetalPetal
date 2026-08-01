//
//  Filter.swift
//  Pods
//
//  Created by YuAo on 22/09/2017.
//

import Foundation
import os

/// Port for read `Value` from `Object`
public protocol OutputPort {
    associatedtype Object: AnyObject
    associatedtype Value
    var object: Object { get }
    var keyPath: KeyPath<Object, Value> { get }
}

/// Port for write `Value` to `Object`
public protocol InputPort {
    associatedtype Object: AnyObject
    associatedtype Value
    var object: Object { get }
    var writableKeyPath: ReferenceWritableKeyPath<Object, Value> { get }
}

public struct Port<Object: AnyObject, Value, Property: KeyPath<Object, Value>> {
    public let object: Object
    let property: Property

    init(_ object: Object, _ property: Property) {
        self.object = object
        self.property = property
    }
}

extension Port: OutputPort {
    public var keyPath: KeyPath<Object, Value> {
        property
    }
}

extension Port: InputPort where Property: ReferenceWritableKeyPath<Object, Value> {
    public var writableKeyPath: ReferenceWritableKeyPath<Object, Value> {
        property
    }
}

public struct ProxyPortTarget {
    public let object: AnyObject
    public let keyPath: AnyKeyPath?
    public let writableKeyPath: AnyKeyPath?

    public init(object: AnyObject, keyPath: AnyKeyPath? = nil, writableKeyPath: AnyKeyPath? = nil) {
        self.object = object
        self.keyPath = keyPath
        self.writableKeyPath = writableKeyPath
    }
}

public protocol ProxyPort {
    var target: ProxyPortTarget { get }
}

private class PortConnectionContext {
    fileprivate var portValueCache: [ObjectIdentifier: [AnyKeyPath: MTIImage]] = [:]
}

private protocol PortConnection {
    var toObject: AnyObject { get }
    func connect(context: PortConnectionContext)
}

private struct PortConnectionsBuildingContext {
    static var contexts: [PortConnectionsBuildingContext] = []

    private var connections: [PortConnection] = []

    static func add(connection: PortConnection) {
        precondition(
            contexts.count > 0,
            """
            No available PortConnectionsBuildingContext. You can only use `=>` operator \
            in FilterGraph.makeImage or FilterGraph.connect function.
            """
        )
        contexts[contexts.count - 1].connections.append(connection)
    }

    static func push() {
        contexts.append(PortConnectionsBuildingContext())
    }

    static func pop() -> [PortConnection] {
        guard let current = contexts.popLast() else {
            fatalError()
        }
        return current.connections
    }
}

public class FilterGraph {
    fileprivate struct Connection<FromPort: OutputPort, ToPort: InputPort>: PortConnection
        where FromPort.Value == MTIImage?, ToPort.Value == MTIImage?
    {
        var fromObject: AnyObject {
            (from as? ProxyPort)?.target.object ?? from.object
        }

        var toObject: AnyObject {
            (to as? ProxyPort)?.target.object ?? to.object
        }

        let from: FromPort
        let to: ToPort

        init(from: FromPort, to: ToPort) {
            self.from = from
            self.to = to
        }

        func connect(context: PortConnectionContext) {
            let fromObjectIdentifier = ObjectIdentifier(fromObject)
            let toObjectIdentifier = ObjectIdentifier(toObject)
            let fromKeyPath = (from as? ProxyPort)?.target.keyPath ?? from.keyPath
            if let c = context.portValueCache[fromObjectIdentifier], let v = c[fromKeyPath] {
                to.object[keyPath: to.writableKeyPath] = v
            } else {
                let value = from.object[keyPath: from.keyPath]
                to.object[keyPath: to.writableKeyPath] = value
                if var c = context.portValueCache[fromObjectIdentifier] {
                    c[fromKeyPath] = value
                    context.portValueCache[fromObjectIdentifier] = c
                } else {
                    if let value {
                        context.portValueCache[fromObjectIdentifier] = [fromKeyPath: value]
                    }
                }
            }
            context.portValueCache[toObjectIdentifier] = [:]
        }
    }

    public class ImageReceiver {
        var image: MTIImage?
    }

    public typealias ImageReceiverInputPort = Port<
        ImageReceiver,
        MTIImage?,
        ReferenceWritableKeyPath<ImageReceiver, MTIImage?>
    >

    private static let builderLock = OSAllocatedUnfairLock()

    /// Performs the `builder` block to create an output image. The `builder` block provides an `input` object
    /// and an `output` port. You can use `=>` operator to connect filters and input/output ports. One and
    /// only one port is allowed to connect to the `output` port.
    public static func makeImage<T>(input: T, builder: (T, ImageReceiverInputPort) -> Void) -> MTIImage? {
        let outputReceiver = ImageReceiver()

        builderLock.lock()
        PortConnectionsBuildingContext.push()
        builder(input, Port(outputReceiver, \.image))
        let connections = PortConnectionsBuildingContext.pop()
        builderLock.unlock()

        let rootConnections = connections.filter { $0.toObject === outputReceiver }
        if rootConnections.count != 1 {
            return nil
        }

        let context = PortConnectionContext()
        for connection in connections {
            connection.connect(context: context)
        }
        return outputReceiver.image
    }

    public static func connect(builder: () -> Void) {
        builderLock.lock()
        PortConnectionsBuildingContext.push()
        builder()
        let connections = PortConnectionsBuildingContext.pop()
        builderLock.unlock()
        let context = PortConnectionContext()
        for connection in connections {
            connection.connect(context: context)
        }
    }

    public static func makeImage(builder: (ImageReceiverInputPort) -> Void) -> MTIImage? {
        makeImage(input: ()) { _, output in
            builder(output)
        }
    }
}

@dynamicMemberLookup
public struct FilterInputPorts<Filter: AnyObject> {
    private let filter: Filter

    public init(filter: Filter) {
        self.filter = filter
    }

    public typealias InputKeyPath = ReferenceWritableKeyPath<Filter, MTIImage?>

    public subscript(dynamicMember keyPath: InputKeyPath) -> Port<Filter, MTIImage?, InputKeyPath> {
        Port(self.filter, keyPath)
    }
}

public extension MTIFilter {
    var outputPort: Port<Self, MTIImage?, KeyPath<Self, MTIImage?>> {
        Port(self, \.outputImage)
    }

    var inputPorts: FilterInputPorts<Self> {
        FilterInputPorts(filter: self)
    }
}

public struct UnaryFilterIOPort<Filter: MTIUnaryFilter>: InputPort, OutputPort {
    public let object: Filter

    public let keyPath: KeyPath<Filter, MTIImage?> = \.outputImage

    public let writableKeyPath: ReferenceWritableKeyPath<Filter, MTIImage?> = \.inputImage
}

public extension MTIUnaryFilter {
    var ioPort: UnaryFilterIOPort<Self> {
        UnaryFilterIOPort(object: self)
    }
}

public extension MTIImage {
    private var _self: MTIImage? {
        self
    }

    struct Port: OutputPort {
        public let object: MTIImage
        public let keyPath: KeyPath<MTIImage, MTIImage?>
    }

    var outputPort: Port {
        Port(object: self, keyPath: \._self)
    }
}

public class PassthroughPort<Value>: InputPort, OutputPort {
    public var object: PassthroughPort {
        self
    }

    private var value: Value

    public var writableKeyPath: ReferenceWritableKeyPath<PassthroughPort, Value> = \.value

    public var keyPath: KeyPath<PassthroughPort, Value> = \.value

    public init(_ value: Value) {
        self.value = value
    }
}

public typealias ImagePassthroughPort = PassthroughPort<MTIImage?>

public extension PassthroughPort where Value == MTIImage? {
    convenience init() {
        self.init(nil)
    }
}

public struct AnyIOPort<Value>: InputPort, OutputPort, ProxyPort {
    public class ObjectProxy {
        var readableValue: Value {
            rReader()
        }

        var writableValue: Value {
            get {
                wReader()
            }
            set {
                wWriter(newValue)
            }
        }

        private var rReader: () -> Value
        private var wReader: () -> Value
        private var wWriter: (Value) -> Void

        init<T>(object: T, keyPath: KeyPath<T, Value>, writableKeyPath: ReferenceWritableKeyPath<T, Value>)
            where T: AnyObject
        {
            rReader = {
                object[keyPath: keyPath]
            }
            wReader = {
                object[keyPath: writableKeyPath]
            }
            wWriter = { value in
                return object[keyPath: writableKeyPath] = value
            }
        }
    }

    public let object: ObjectProxy
    public let keyPath: KeyPath<ObjectProxy, Value> = \ObjectProxy.readableValue
    public let writableKeyPath: ReferenceWritableKeyPath<ObjectProxy, Value> = \ObjectProxy.writableValue

    public let target: ProxyPortTarget

    public init<T>(_ port: T) where T: InputPort, T: OutputPort, T.Value == Value {
        object = ObjectProxy(
            object: port.object,
            keyPath: port.keyPath,
            writableKeyPath: port.writableKeyPath
        )
        target = ProxyPortTarget(
            object: port.object,
            keyPath: port.keyPath,
            writableKeyPath: port.writableKeyPath
        )
    }
}

public extension AnyIOPort {
    init(_ filter: some MTIUnaryFilter) where Value == MTIImage? {
        self.init(filter.ioPort)
    }
}

public struct AnyInputPort<Value>: InputPort, ProxyPort {
    public class ObjectProxy {
        var writableValue: Value {
            get {
                wReader()
            }
            set {
                wWriter(newValue)
            }
        }

        private var wReader: () -> Value
        private var wWriter: (Value) -> Void

        init<T>(object: T, writableKeyPath: ReferenceWritableKeyPath<T, Value>) where T: AnyObject {
            wReader = {
                object[keyPath: writableKeyPath]
            }
            wWriter = { value in
                return object[keyPath: writableKeyPath] = value
            }
        }
    }

    public let object: ObjectProxy
    public let writableKeyPath: ReferenceWritableKeyPath<ObjectProxy, Value> = \ObjectProxy.writableValue

    public let target: ProxyPortTarget

    public init<T>(_ port: T) where T: InputPort, T.Value == Value {
        object = ObjectProxy(object: port.object, writableKeyPath: port.writableKeyPath)
        target = ProxyPortTarget(object: port.object, keyPath: nil, writableKeyPath: port.writableKeyPath)
    }
}

public extension AnyInputPort {
    init(_ filter: some MTIUnaryFilter) where Value == MTIImage? {
        self.init(filter.ioPort)
    }
}

public struct AnyOutputPort<Value>: OutputPort, ProxyPort {
    public class ObjectProxy {
        var readableValue: Value {
            rReader()
        }

        private var rReader: () -> Value
        init<T>(object: T, keyPath: KeyPath<T, Value>) where T: AnyObject {
            rReader = {
                object[keyPath: keyPath]
            }
        }
    }

    public let object: ObjectProxy
    public let keyPath: KeyPath<ObjectProxy, Value> = \ObjectProxy.readableValue

    public let target: ProxyPortTarget

    public init<T>(_ port: T) where T: OutputPort, T.Value == Value {
        object = ObjectProxy(object: port.object, keyPath: port.keyPath)
        target = ProxyPortTarget(object: port.object, keyPath: port.keyPath, writableKeyPath: nil)
    }
}

public extension AnyOutputPort {
    init(_ filter: some MTIFilter) where Value == MTIImage? {
        self.init(filter.outputPort)
    }
}

public extension AnyOutputPort where Value == MTIImage? {
    init(_ image: MTIImage) {
        self.init(image.outputPort)
    }
}

public protocol OutputPortProvider {
    associatedtype Port: OutputPort
    var outputPort: Port { get }
}

public protocol InputPortProvider {
    associatedtype Port: InputPort
    var inputPort: Port { get }
}

extension MTIImage: OutputPortProvider {}

infix operator =>: AdditionPrecedence

private extension OutputPort where Value == MTIImage? {
    func connect<Input: InputPort>(to port: Input) where Input.Value == Self.Value {
        let connection = FilterGraph.Connection<Self, Input>(from: self, to: port)
        PortConnectionsBuildingContext.add(connection: connection)
    }
}

@discardableResult
public func => <Output: OutputPort, Input: InputPort>(lhs: Output, rhs: Input) -> Input
    where Input.Value == Output.Value, Output.Value == MTIImage?
{
    lhs.connect(to: rhs)
    return rhs
}

@discardableResult
public func => <Output: OutputPortProvider, Input: InputPort>(lhs: Output, rhs: Input) -> Input
    where Output.Port.Value == Input.Value, Input.Value == MTIImage?
{
    lhs.outputPort.connect(to: rhs)
    return rhs
}

@discardableResult
public func => <Output: OutputPortProvider, Input: MTIUnaryFilter>(lhs: Output, rhs: Input) -> Input
    where Output.Port.Value == MTIImage?
{
    lhs.outputPort.connect(to: rhs.ioPort)
    return rhs
}

@discardableResult
public func => <Input: InputPort>(lhs: some MTIFilter, rhs: Input) -> Input where Input.Value == MTIImage? {
    lhs.outputPort.connect(to: rhs)
    return rhs
}

@discardableResult
public func => <Input: MTIUnaryFilter>(lhs: some MTIFilter, rhs: Input) -> Input {
    lhs.outputPort.connect(to: rhs.ioPort)
    return rhs
}

@discardableResult
public func => <Output: OutputPort, Input: MTIUnaryFilter>(lhs: Output, rhs: Input) -> Input
    where Output.Value == MTIImage?
{
    lhs.connect(to: rhs.ioPort)
    return rhs
}

@discardableResult
public func => <Input: InputPortProvider>(lhs: some MTIFilter, rhs: Input) -> Input
    where Input.Port.Value == MTIImage?
{
    lhs.outputPort.connect(to: rhs.inputPort)
    return rhs
}

@discardableResult
public func => <Output: OutputPort, Input: InputPortProvider>(lhs: Output, rhs: Input) -> Input
    where Output.Value == Input.Port.Value, Output.Value == MTIImage?
{
    lhs.connect(to: rhs.inputPort)
    return rhs
}

@discardableResult
public func => <Output: OutputPortProvider, Input: InputPortProvider>(lhs: Output, rhs: Input) -> Input
    where Output.Port.Value == Input.Port.Value, Input.Port.Value == MTIImage?
{
    lhs.outputPort.connect(to: rhs.inputPort)
    return rhs
}

#if canImport(Combine)

import Combine

@available(iOS 13.0, macOS 10.15, *)
public extension FilterGraph {
    static func makePublisher<T: Publisher>(
        upstream: T,
        builder: @escaping (T.Output, ImageReceiverInputPort) -> Void
    ) -> AnyPublisher<MTIImage?, Never> where T.Failure == Never {
        upstream.map { value -> MTIImage? in
            return makeImage(input: value, builder: builder)
        }.eraseToAnyPublisher()
    }
}

#endif
