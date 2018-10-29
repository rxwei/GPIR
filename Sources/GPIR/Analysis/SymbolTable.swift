//
//  SymbolTable.swift
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

open class SymbolTableAnalysis : AnalysisPass {
    public typealias Body = Function
    public typealias Result = [String : Definition]
    open class func run(on body: Body) -> Result {
        var table: Result = [:]
        for bb in body {
            for argument in bb.arguments {
                guard let name = argument.name else { continue }
                table[name] = .argument(argument)
            }
            for inst in bb {
                guard let name = inst.name else { continue }
                table[name] = .instruction(inst)
            }
        }
        return table
    }
}

public extension Function {
    func element(named name: String) -> Definition? {
        /// Guaranteed not to throw
        let table = analysis(from: SymbolTableAnalysis.self)
        return table[name]
    }
}