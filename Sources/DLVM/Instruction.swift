//
//  Instruction.swift
//  DLVM
//
//  Created by Richard Wei on 12/25/16.
//
//

public enum LogicOperator {
    case and, or, xor
}

public enum ComparisonPredicate {
    case lessThan, lessThanOrEqualTo
    case greaterThan, greaterThanOrEqualTo
    case equalTo, notEqualTo
}

public enum ArithmeticOperator {
    case add, subtract, multiply, divide, min, max
    case truncateDivide, floorDivide, modulo, power, mean
}

public enum ElementwiseFunction {
    case sigmoid, relu, tanh
    case log, exp, neg, sign, square, sqrt, round, rsqrt, ceil, floor
    case tan, cos, sin, acos, asin, atan
    case lgamma, digamma, erf, erfc, rint

}

public enum BinaryIntegrationFunction {
    case crossEntropy
}

public enum ReductionFunction {
    case logical(LogicOperator)
    case arithmetic(ArithmeticOperator)
}

public enum AggregationFunction {
    case softmax, logSoftmax, argmax, argmin
    case scan(ReductionFunction)
}

public protocol Instruction : class, Operator {
    weak var parent: BasicBlock? { get set }
}

public protocol NestingInstruction : Instruction {
    var body: BasicBlock { get set }
}

public protocol DefiningInstruction : Instruction, NamedValue {
    var name: String { get set }
    var type: DataType { get set }
    var shape: TensorShape { get set }
}

public protocol Operator : class {
    var operands: [Value] { get }
}

/// Abstract class for unary instruction
public protocol UnaryOperator : Operator {
    var operand: Value { get set }
}

public extension UnaryOperator {
    public var operands: [Value] {
        return [operand]
    }
}

/// Abstract class for binary instruction
public protocol BinaryOperator : Operator {
    var firstOperand: Value { get set }
    var secondOperand: Value { get set }
}

public extension BinaryOperator {
    public var operands: [Value] {
        return [firstOperand, secondOperand]
    }
}

public protocol FunctionCallInstruction : DefiningInstruction {
    associatedtype Function
    var function: Function { get set }
}

/// Unary function calls
public typealias UnaryCallInstruction = FunctionCallInstruction & UnaryOperator

/// Binary function calls
public typealias BinaryCallInstruction = FunctionCallInstruction & BinaryOperator

public class HomomorphicUnaryInstruction<Function> : UnaryCallInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var function: Function
    public var operand: Value

    public init(name: String, function: Function, operand: Value) {
        self.name = name
        self.type = operand.type
        self.shape = operand.shape
        self.function = function
        self.operand = operand
    }
}

public class HomomorphicBinaryInstruction<Function> : BinaryCallInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var function: Function
    public var firstOperand: Value
    public var secondOperand: Value
    
    public init(name: String, function: Function, firstOperand: Value, secondOperand: Value) {
        self.name = name
        self.function = function
        self.type = firstOperand.type
        /// Broadcasting
        self.shape = firstOperand.shape.rank > secondOperand.shape.rank
                   ? firstOperand.shape : secondOperand.shape
        self.firstOperand = firstOperand
        self.secondOperand = secondOperand
    }
}

/// Shape-preserving, type-preserving (homomorphic) transformation instructions
public typealias ElementwiseInstruction = HomomorphicUnaryInstruction<ElementwiseFunction>
public typealias AggregationInstruction = HomomorphicUnaryInstruction<AggregationFunction>
public typealias BinaryReductionInstruction = HomomorphicBinaryInstruction<BinaryIntegrationFunction>
public typealias ArithmeticInstruction = HomomorphicBinaryInstruction<ArithmeticOperator>
public typealias LogicInstruction = HomomorphicBinaryInstruction<LogicOperator>

/// Reduction instruction
/// - Note: We are assuming that reduction instruction takes any tensor and apply
/// the reduction function between elements contiguously in memory.
/// At the end of the day we will want shape-based reduction, e.g. reducing a
/// dimension from the shape. But this is not a priority.
/// Q: Why do we still want this feature? A: TensorFlow has it.
public class ReductionInstruction : UnaryCallInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var function: ReductionFunction
    public var operand: Value
    
    public init(name: String, function: ReductionFunction, operand: Value) {
        self.name = name
        self.type = operand.type
        self.shape = .scalar
        self.function = function
        self.operand = operand
    }
}

/// Comparison instruction
/// - shape: [A] -> [A]
/// - type: _ -> Bool
public final class ComparisonInstruction : BinaryCallInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var function: ComparisonPredicate
    public var firstOperand: Value
    public var secondOperand: Value

    public init(name: String, function: ComparisonPredicate,
                firstOperand: Value, secondOperand: Value) {
        self.name = name
        self.type = .bool
        self.shape = firstOperand.shape
        self.function = function
        self.firstOperand = firstOperand
        self.secondOperand = secondOperand
    }
}

/// Generic tensor multiplication instruction (GETT operation)
public final class TensorMultiplicationInstruction : DefiningInstruction, BinaryOperator {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var firstOperand: Value
    public var secondOperand: Value

    public init(name: String, firstOperand: Value, secondOperand: Value) {
        self.name = name
        self.type = firstOperand.type
        let newShape = (firstOperand.shape ⊗ secondOperand.shape) ?? firstOperand.shape
        self.shape = newShape
        self.firstOperand = firstOperand
        self.secondOperand = secondOperand
    }
}

/// Matrix multiplication instruction (GEMM operation)
/// - Note: This only applies to the two inner dimensions
public final class MatrixMultiplicationInstruction : DefiningInstruction, BinaryOperator {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var firstOperand: Value
    public var secondOperand: Value
    public init(name: String, firstOperand: Value, secondOperand: Value) {
        self.name = name
        self.type = firstOperand.type
        let newShape = firstOperand.shape.matrixMultiplied(by: secondOperand.shape) ?? firstOperand.shape
        self.shape = newShape
        self.firstOperand = firstOperand
        self.secondOperand = secondOperand
    }
}

/// Concatenation instruction
/// Concatenates multiple tensors along an axis dimension
public final class ConcatenationInstruction : DefiningInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var operands: [Value]
    public var axis: Int

    public init(name: String, operands: [Value], axis: Int) {
        precondition(!operands.isEmpty)
        self.name = name
        self.type = operands[0].type
        let firstShape = operands[0].shape
        let newShape = operands.dropFirst().reduce(firstShape, { acc, x in
            acc?.concatenating(with: x.shape, alongDimension: axis)
        }) ?? firstShape
        self.shape = newShape
        self.operands = Array(operands)
        self.axis = axis
    }
}

public protocol CastInstruction : DefiningInstruction, UnaryOperator {
    associatedtype Target
    var target: Target { get set }
    init(name: String, operand: Value, target: Target)
}

/// Shape-cast instruction
/// Casts the shape of a tensor to another
/// - Precondition: Target shape must be of the same contiguous size
/// - Note: We will want to be able to shape-cast between different contiguous
/// sizes (Q: Reason? A: TensorFlow does.). This should be done after we
/// introduce **slicing**-related instructions.
public final class ShapeCastInstruction : CastInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var operand: Value
    public var target: TensorShape

    public init(name: String, operand: Value, target: TensorShape) {
        self.name = name
        self.type = operand.type
        self.shape = target
        self.operand = operand
        self.target = target
    }
}

/// Type-cast instruction
/// Casts the element type of a tensor to another
/// - Precondition: The current type must be castable to the target shape
/// - Note: Nope, this is not bitcast
public final class TypeCastInstruction : CastInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var operand: Value
    public var target: DataType

    public init(name: String, operand: Value, target: DataType) {
        self.name = name
        self.type = target
        self.shape = operand.shape
        self.operand = operand
        self.target = target
    }
}

/// Load instruction
/// - Note: Not to be confused with *load* in LLVM. It "loads" or "consumes"
/// an input from the training/inference batch, in terms of neural networks.
public final class LoadInstruction : DefiningInstruction {
    public var parent: BasicBlock?
    public var name: String
    public var type: DataType
    public var shape: TensorShape
    public var source: Value

    public var operands: [Value] {
        return [source]
    }

    public init(name: String, source: Value) {
        self.name = name
        self.type = source.type
        self.shape = source.shape
        self.source = source
    }
}

/// Store instruction
/// - Note: Not to be confused with *store* in LLVM. It actually outputs
/// the computed tensor as an output of the neural network. Maybe we
/// want to changed the name to something like "export", but "store" is a
/// nice counterpart of "load".
public final class StoreInstruction : Instruction {
    public var parent: BasicBlock?
    public var source: Value
    public var destination: Value

    public var operands: [Value] {
        return [source, destination]
    }

    public init(source: Value, destination: Value) {
        self.source = source
        self.destination = destination
    }
}


/// Loop instruction
public final class LoopInstruction : NestingInstruction {
    public enum Condition {
        case times(Value)
        case untilEqual(Value, Value)
    }
    
    public var parent: BasicBlock?
    public var condition: Condition
    public var body: BasicBlock

    public var operands: [Value] {
        switch condition {
        case let .times(times): return [times]
        case let .untilEqual(v1, v2): return [v1, v2]
        }
    }

    public init(condition: Condition, body: BasicBlock) {
        self.condition = condition
        self.body = body
    }
}
