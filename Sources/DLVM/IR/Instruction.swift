//
//  Instruction.swift
//  DLVM
//
//  Created by Richard Wei on 12/25/16.
//
//

public final class Instruction : IRSubUnit {
    public enum Kind {
        case control(Control)
        case operation(Def<Operation>)
    }
    public typealias Parent = BasicBlock
    public let kind: Kind
    public unowned var parent: BasicBlock
    public internal(set) var analysisManager: AnalysisManager<Instruction> = AnalysisManager()
    public internal(set) var transformManager: TransformManager<Instruction> = TransformManager()

    public required init(kind: Kind, parent: BasicBlock) {
        self.kind = kind
        self.parent = parent
    }

    public static func control(_ control: Control, parent: BasicBlock) -> Instruction {
        return self.init(kind: .control(control), parent: parent)
    }

    public static func operation(_ operation: Def<Operation>, parent: BasicBlock) -> Instruction {
        return self.init(kind: .operation(operation), parent: parent)
    }
}

public enum Control {
    /// Store use to global value
    case store(Use, to: Def<GlobalValue>)
    /// Yield value to output
    case yield(Use, to: Def<Output>)
    /// Unconditionally branch to basic block
    case br(BasicBlock, [Use])
    /// Conditional branch depending on the value
    case condBr(Use, BasicBlock, BasicBlock)
    /// Return
    case ret(Use?)
    /// Continue to successor sections
    case cont
    /// Pull a value from the recurrent input batch in the current epoch
    /// and pass the value as an argument to the first basic block argument
    case pull(Def<Placeholder>, BasicBlock, BasicBlock)
}

public enum Operation {
    /// Get the value of the non-recurrent input
    /// - Precondition: placeholder must **not** be recurrent
    case get(Def<Placeholder>)
    /// Scan operation with optional axis
    /// If axis is not given, scan is performed on contiguous elements
    case scan(AssociativeOp, Use, axis: Int?)
    /// Reduction operation with optional axis
    /// If axis is not given, reduction is performed on contiguous elements
    case reduce(AssociativeOp, Use, axis: Int?)
    /// Monomorphic unary operation
    case unary(UnaryOp, Use)
    /// Monomorphic binary operation
    case binary(BinaryOp, Use, Use)
    /// Matrix multiplication operation
    case matMul(Use, Use)
    /// Concatenation operation
    case concat(TensorShape, DataType, [Use], axis: Int)
    /// Transpose
    case transpose(Use)
    /// Type cast operation
    case typeCast(Use, DataType)
    /// Shape cast operation
    case shapeCast(Use, TensorShape)
    /// Subtensor addressing
    case subtensor(Use, TensorIndex)
    /// Intrinsic
    case intrinsic(TensorShape, DataType, Intrinsic, [Use])
    /// Element in the immediate dimension
    case element(Use, Int)
    /// Function call
    case call(TensorShape, DataType, Function, [Use])
    /// Differentiate
    case diff(Function, Use, wrt: Def<Argument>)
}

// MARK: - Instruction properties
public extension Instruction {
    var definition: Definition? {
        guard case let .operation(def) = kind else {
            return nil
        }
        return def
    }
}

extension Instruction : MaybeNamed {
    public var name: String? {
        guard case let .operation(def) = kind else { return nil }
        return def.name
    }
}

// MARK: - Control flow predicates
public extension Instruction {
    var isOperation: Bool {
        if case .operation = kind { return true }
        return false
    }
    
    var isControl: Bool {
        if case .control = kind { return true }
        return false
    }
    
    var isTerminator: Bool {
        switch kind {
        case .control(let ctrl): return ctrl.isTerminator
        default: return false
        }
    }

    var isReturn: Bool {
        switch kind {
        case .control(let ctrl): return ctrl.isReturn
        default: return false
        }
    }

    var isContinue: Bool {
        switch kind {
        case .control(let ctrl): return ctrl.isContinue
        default: return false
        }
    }

    var isYield: Bool {
        switch kind {
        case .control(let ctrl): return ctrl.isYield
        default: return false
        }
    }

    var isExit: Bool {
        switch kind {
        case .control(let ctrl): return ctrl.isExit
        default: return false
        }
    }
}

public extension Control {
    var isTerminator: Bool {
        switch self {
        case .br, .condBr, .ret, .pull, .cont:
            return true
        default:
            return false
        }
    }

    var isReturn: Bool {
        switch self {
        case .ret: return true
        default: return false
        }
    }

    var isContinue: Bool {
        switch self {
        case .cont: return true
        default: return false
        }
    }

    var isYield: Bool {
        switch self {
        case .yield: return true
        default: return false
        }
    }

    var isExit: Bool {
        return isReturn || isContinue
    }
}

extension Operation : Value {

    public var type: DataType {
        switch self {
        case let .binary(.associative(.arithmetic), op1, _):
            return op1.type
        case .binary(.associative(.boolean), _, _),
             .binary(.comparison, _, _):
            return .bool
        case let .matMul(op1, _):
            return op1.type
        case let .unary(_, op),
             let .reduce(_, op, _),
             let .scan(_, op, _):
            return op.type
        case let .concat(_, type, _, _):
            return type
        case let .transpose(op):
            return op.type
        case let .typeCast(_, t):
            return t
        case let .shapeCast(op, _):
            return op.type
        case let .get(ph):
            return ph.type
        case let .call(_, type, _, _):
            return type
        case let .element(op, _),
             let .subtensor(op, _):
            return op.type
        case let .intrinsic(_, type, _, _):
            return type
        case let .diff(_, use, wrt: _):
            return use.type
        }
    }

    public var shape: TensorShape {
        switch self {
        case let .matMul(op1, op2):
            return op1.shape.matrixMultiplied(with: op2.shape) ?? op1.shape
        case let .binary(_, op1, op2):
            return op1.shape.mutuallyBroadcasted(with: op2.shape) ?? op1.shape
        case let .unary(_, op),
             let .scan(_, op, axis: _):
            return op.shape
        case .reduce(_, _, axis: nil):
            return .scalar
        case let .reduce(_, op, axis: axis?):
            return op.shape.droppingDimension(axis)
        case let .concat(shape, _, _, _):
            return shape
        case let .transpose(op):
            return op.shape
        case let .typeCast(op, _):
            return op.shape
        case let .shapeCast(_, s):
            return s
        case let .get(ph):
            return ph.shape
        case let .call(shape, _, _, _):
            return shape
        case let .element(op, _):
            return op.shape.dropFirst()
        case let .subtensor(op, idx):
            return op.shape[idx] ?? op.shape
        case let .intrinsic(shape, _, _, _):
            return shape
        case let .diff(_, use, wrt: _):
            return use.shape
        }
    }

    public static var scope: Scope = .local

}

extension Control : User {
    public var operands: [Use] {
        switch self {
        case .condBr(let op, _, _),
             .yield(let op, _),
             .store(let op, _),
             .ret(let op?):
            return [op]
        default:
            return []
        }
    }
}

extension Operation : User {
    public var operands: [Use] {
        switch self {
        case let .binary(_, op1, op2),
             let .matMul(op1, op2):
            return [op1, op2]
        case .concat(_, _, let uses, axis: _):
            return uses
        case let .transpose(op):
            return [op]
        case let .unary(_, op),
             let .reduce(_, op, _),
             let .scan(_, op, _),
             let .shapeCast(op, _),
             let .typeCast(op, _):
            return [op]
        case .call(_, _, _, let ops),
             .intrinsic(_, _, _, let ops):
            return ops
        case .get, .diff:
            return []
        case let .subtensor(op, _),
             let .element(op, _):
            return [op]
        }
    }
}

extension Instruction : User {
    public var operands: [Use] {
        switch kind {
        case .control(let ctrl): return ctrl.operands
        case .operation(let oper): return oper.operands
        }
    }
}

public extension Def where ValueType : User {
    public var operands: [Use] {
        return value.operands
    }
}

public extension Instruction {
    func substituting(_ actualUse: Use, for use: Use) -> Instruction {
        switch kind {
        case let .control(ctrl):
            return .control(ctrl.substituting(actualUse, for: use), parent: parent)
        case let .operation(def):
            let oper = def.value.substituting(actualUse, for: use)
            let newDef = Def<Operation>(name: def.name, value: oper)
            return .operation(newDef, parent: parent)
        }
    }

    var indexInParent: Int? {
        return parent.index(of: self)
    }

    func removeFromParent() {
        parent.remove(self)
    }
}

public extension Control {
    func substituting(_ newUse: Use, for use: Use) -> Control {
        switch self {
        case .store(use, to: let dest):
            return .store(newUse, to: dest)
        case .condBr(use, let thenBB, let elseBB):
            return .condBr(newUse, thenBB, elseBB)
        case .yield(use, to: let dest):
            return .yield(newUse, to: dest)
        case .ret(use?):
            return .ret(newUse)
        default:
            return self
        }
    }
}

public extension Operation {
    func substituting(_ newUse: Use, for use: Use) -> Operation {
        let condSubst = {$0 == use ? newUse : $0}
        switch self {
        case .unary(let fun, use):
            return .unary(fun, newUse)
        case .binary(let fun, use, let use2):
            return .binary(fun, newUse, use2)
        case .binary(let fun, let use1, use):
            return .binary(fun, use1, newUse)
        case .binary(let fun, use, use):
            return .binary(fun, newUse, newUse)
        case let .concat(shape, type, uses, axis: axis):
            return .concat(shape, type, uses.map(condSubst), axis: axis)
        case .transpose(use):
            return .transpose(newUse)
        case .reduce(let fun, use, axis: let axis):
            return .reduce(fun, newUse, axis: axis)
        case .matMul(use, let use2):
            return .matMul(newUse, use2)
        case .matMul(let use1, use):
            return .matMul(use1, newUse)
        case .matMul(use, use):
            return .matMul(newUse, newUse)
        case .shapeCast(use, let shape):
            return .shapeCast(newUse, shape)
        case .typeCast(use, let type):
            return .typeCast(newUse, type)
        case .diff(let fun, use, wrt: let arg):
            return .diff(fun, newUse, wrt: arg)
        default:
            return self
        }
    }
}

public extension Control {
    var usedPlaceholders: ObjectSet<Def<Placeholder>> {
        return []
    }
}

public extension Operation {
    var usedPlaceholders: ObjectSet<Def<Placeholder>> {
        switch self {
        case .get(let ph):
            return [ph]
        default:
            return []
        }
    }

    var usedArguments: ObjectSet<Def<Argument>> {
        var arguments: ObjectSet<Def<Argument>> = []
        for case let .argument(arg) in operands.map({$0.kind}) {
            arguments.insert(arg)
        }
        return arguments
    }
}

public extension Instruction {
    var usedPlaceholders: ObjectSet<Def<Placeholder>> {
        switch kind {
        case .control(let ctrl): return ctrl.usedPlaceholders
        case .operation(let oper): return oper.value.usedPlaceholders
        }
    }

    var usedArguments: ObjectSet<Def<Argument>> {
        var arguments: ObjectSet<Def<Argument>> = []
        for case let .argument(arg) in operands.map({$0.kind}) {
            arguments.insert(arg)
        }
        return arguments
    }
}

public extension BasicBlock {
    var usedPlaceholders: ObjectSet<Def<Placeholder>> {
        var placeholders: ObjectSet<Def<Placeholder>> = []
        for inst in self {
            placeholders.formUnion(inst.usedPlaceholders)
        }
        return placeholders
    }

    var usedArguments: ObjectSet<Def<Argument>> {
        var arguments: ObjectSet<Def<Argument>> = []
        for inst in self {
            arguments.formUnion(inst.usedArguments)
        }
        return arguments
    }
}
