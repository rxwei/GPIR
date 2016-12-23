//
//  Expression.swift
//  TEL
//
//  Created by Richard Wei on 11/6/16.
//
//

import DLVM

//
//infix operator • : MultiplicationPrecedence
//infix operator ~
//
//public extension Expression {
//
//    @inline(__always)
//    public static func +(lhs: Expression, rhs: Expression) -> Expression {
//        return .add(lhs, rhs)
//    }
//
//    @inline(__always)
//    public static func *(lhs: Expression, rhs: Expression) -> Expression {
//        return .mul(lhs, rhs)
//    }
//
//    @inline(__always)
//    public static func •(lhs: Expression, rhs: Expression) -> Expression {
//        return .product(lhs, rhs)
//    }
//
//    @inline(__always)
//    public static prefix func -(rhs: Expression) -> Expression {
//        return .negative(rhs)
//    }
//
//    @inline(__always)
//    public static func -(lhs: DataType, rhs: Expression) -> Expression {
//        return .scalarComplement(lhs, rhs)
//    }
//    
//    @inline(__always)
//    public static func ~(lhs: Expression, rhs: String) -> Expression {
//        return .layer(lhs, name: rhs)
//    }
//    
//}
//
//@inline(__always)
//public func sigmoid<T: TensorDataProtocol>(_ expression: Expression<T>) -> Expression<T> {
//    return .sigmoid(expression)
//}
//
//@inline(__always)
//public func relu<T: TensorDataProtocol>(_ expression: Expression<T>) -> Expression<T> {
//    return .relu(expression)
//}
//
//@inline(__always)
//public func tanh<T: TensorDataProtocol>(_ expression: Expression<T>) -> Expression<T> {
//    return .tanh(expression)
//}
//
//@inline(__always)
//public func softmax<T: TensorDataProtocol>(_ expression: Expression<T>) -> Expression<T> {
//    return .softmax(expression)
//}
//
//@inline(__always)
//public func min<T: TensorDataProtocol>(_ lhs: Expression<T>, _ rhs: Expression<T>) -> Expression<T> {
//    return .min(lhs, rhs)
//}
//
//@inline(__always)
//public func max<T: TensorDataProtocol>(_ lhs: Expression<T>, _ rhs: Expression<T>) -> Expression<T> {
//    return .max(lhs, rhs)
//}