//
//  Value.swift
//  DLVM
//
//  Created by Richard Wei on 1/10/17.
//
//

public protocol User {
    var operands: [Use] { get }
}

public protocol Usee : class {
    associatedtype UserType : User
    var users: NamedObjectSet<UserType> { get }
}

internal protocol ManagedUsee : Usee {
    var users: NamedObjectSet<UserType> { get set }
}

internal extension ManagedUsee {
    func addUser(_ user: UserType) {
        users.insert(user)
    }

    func removeUser(_ user: UserType) {
        users.remove(user)
    }

    func removeAllUsers() {
        users.removeAll()
    }
}

public enum Scope {
    case global
    case local
    case none
}

public protocol Value {
    var shape: TensorShape { get }
    var type: DataType { get }
    static var scope: Scope { get }
}

public enum Literal {
    case scalar(ScalarLiteral)
    case tensor(TensorLiteral)
}

public enum ScalarLiteral {
    case int(Int), float(Double), bool(Bool)

    public var typeBase: DataType.Base {
        switch self {
        case .bool: return .bool
        case .int: return .int
        case .float: return .float
        }
    }
}

public enum TensorLiteral {
    case elements([ScalarLiteral])
    case random(from: ScalarLiteral, to: ScalarLiteral)
    case repeating(ScalarLiteral)

    public var typeBase: DataType.Base {
        switch self {
        case let .elements(elements):
            return elements[0].typeBase
        case let .random(from: lowerbound, to: _):
            return lowerbound.typeBase
        case let .repeating(value):
            return value.typeBase
        }
    }
}

public struct LiteralValue : Value {
    public var shape: TensorShape
    public var type: DataType
    public var literal: ScalarLiteral
    public static let scope: Scope = .none

    public init(shape: TensorShape, type: DataType, literal: ScalarLiteral) {
        self.shape = shape
        self.type = type
        self.literal = literal
    }
}

public protocol Named {
    var name: String { get set }
}

public enum Global {
    case value(Def<GlobalValue>)
    case placeholder(Def<Placeholder>)
}

public struct GlobalValue : Value {
    public enum Kind {
        case variable, constant
    }
    public var kind: Kind
    public var shape: TensorShape
    public var type: DataType
    public var initializer: Literal
    public static let scope: Scope = .global

    public init(kind: Kind, shape: TensorShape, type: DataType, initializer: Literal) {
        self.kind = kind
        self.shape = shape
        self.type = type
        self.initializer = initializer
    }
}

public struct Placeholder : Value {
    public var shape: TensorShape
    public var type: DataType
    public static var scope: Scope = .global

    public init(shape: TensorShape, type: DataType) {
        self.shape = shape
        self.type = type
    }
}
