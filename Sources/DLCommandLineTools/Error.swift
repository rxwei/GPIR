//
//  Error.swift
//  DLCommandLineTools
//
//  Copyright 2016-2017 The DLVM Team.
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

import Foundation
import Basic
import Utility

public enum DLError: Swift.Error {
    /// No input files were specified.
    case noInputFiles

    /// An input file is invalid.
    // NOTE: To be removed when PathArgument init checks for invalid paths.
    case invalidInputFile(AbsolutePath)

    /// The number of input files and output paths do not match.
    case inputOutputCountMismatch
}

extension DLError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noInputFiles:
            return "no input files"
        case .invalidInputFile(let path):
            return "invalid input path: \(path.prettyPath())"
        case .inputOutputCountMismatch:
            return "number of inputs and outputs do not match"
        }
    }
}

public func print(error: Any) {
    let writer = InteractiveWriter.stderr
    writer.write("error: ", inColor: .red, bold: true)
    writer.write("\(error)")
    writer.write("\n")
}

public func handle(error: Any) {
    switch error {
    case ArgumentParserError.expectedArguments(let parser, _):
        print(error: error)
        parser.printUsage(on: stderrStream)
    default:
        print(error: error)
    }
}

/// This class is used to write on the underlying stream.
///
/// If underlying stream is a not tty, the string will be written in without any
/// formatting.
private final class InteractiveWriter {

    /// The standard error writer.
    static let stderr = InteractiveWriter(stream: stderrStream)

    /// The terminal controller, if present.
    let term: TerminalController?

    /// The output byte stream reference.
    let stream: OutputByteStream

    /// Create an instance with the given stream.
    init(stream: OutputByteStream) {
        self.term = (stream as? LocalFileOutputByteStream).flatMap(TerminalController.init(stream:))
        self.stream = stream
    }

    /// Write the string to the contained terminal or stream.
    func write(_ string: String, inColor color: TerminalController.Color = .noColor, bold: Bool = false) {
        if let term = term {
            term.write(string, inColor: color, bold: bold)
        } else {
            stream <<< string
            stream.flush()
        }
    }
}
