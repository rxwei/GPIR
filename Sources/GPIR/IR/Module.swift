//
//  Module.swift
//  GPIR
//
//  Copyright 2018 The GPIR Team.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

/// Module representing a neural network
public final class Module : IRCollection {
    public enum Stage {
        case raw, optimizable
    }

    public typealias Base = OrderedSet<Function>
    public typealias Element = Function
    public typealias Index = Int

    public var name: String
    public internal(set) var stage: Stage
    public var elements: OrderedSet<Function> = []
    public var variables: OrderedSet<Variable> = []
    public var structs: OrderedSet<StructType> = []
    public var enums: OrderedSet<EnumType> = []
    public var typeAliases: OrderedSet<TypeAlias> = []
    public let passManager: PassManager<Module> = PassManager()

    public init(name: String, stage: Stage = .raw) {
        self.name = name
        self.stage = stage
    }

    public var canApplyTransforms: Bool {
        return true
    }
}

/// - Note: This is a workaround for a type checker bug in Swift 4
public extension Module {
    typealias SubSequence = Slice<Module>

    func append(_ newElement: Element) {
        elements.append(newElement)
        newElement.parent = self
        invalidatePassResults()
    }

    func insert(_ newElement: Element, at index: Base.Index) {
        elements.insert(newElement, at: index)
        newElement.parent = self
        invalidatePassResults()
    }

    func insert(_ newElement: Element, after other: Element) {
        elements.insert(newElement, after: other)
        newElement.parent = self
        invalidatePassResults()
    }

    func insert(_ newElement: Element, before other: Element) {
        elements.insert(newElement, before: other)
        newElement.parent = self
        invalidatePassResults()
    }
}

extension Module {
    public func write(toFile path: String) throws {
        var contents = ""
        write(to: &contents)
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

/// - Note: Name lookup for IR units is implemented as a cached analysis
/// pass, but we don't yet have caching infrastructure for non-IRUnits.
/// Thus name lookup for types and global variables is temporarily implemented
/// as linear search.
public extension Module {
    func variable(named name: String) -> Variable? {
        return variables.first(where: { $0.name == name })
    }

    func `struct`(named name: String) -> StructType? {
        return structs.first(where: { $0.name == name })
    }

    func `enum`(named name: String) -> EnumType? {
        return enums.first(where: { $0.name == name })
    }

    func typeAlias(named name: String) -> TypeAlias? {
        return typeAliases.first(where: { $0.name == name })
    }
}
