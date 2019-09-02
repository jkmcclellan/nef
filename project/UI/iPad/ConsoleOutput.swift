//  Copyright © 2019 The nef Authors.

import Foundation
import Common
import BowEffects

class iPadConsole: ConsoleOutput {

    func printError(information: String) {
        if !information.isEmpty {
            print("information: \(information)")
        }
        print("error:\(scriptName) could not build Playground compatible with iPad ❌")
    }

    func printHelp() {
        print("\(scriptName) --package <package path> --to <output path> --name <playground name>")
        print("""

                    package: path to Package.swift page. ex. `/home/Package.swift`
                    to: path where Playground are saved to. ex. `/home`
                    name: name for the Playground. ex. `Nef`

              """)
    }
    
    func printStep<E: Error>(information: String) -> IO<E, ()> {
        return IO.invoke { print(information, separator: " ", terminator: "") }
    }
    
    func printSubstep<E: Error>(information: String) -> IO<E, ()> {
        return IO.invoke { print("\t\(information)", separator: " ", terminator: "\n") }
    }
    
    func printStatus<E: Error>(success: Bool) -> IO<E, ()> {
        return IO.invoke { print(" \(success ? "✅" : "❌")", separator: "", terminator: "\n") }
    }
}
