//  Copyright © 2019 The nef Authors.

import Foundation

extension ConsoleOutput {

    func printError(information: String) {
        print("""
              trace: \(information)
              error:\(scriptName) could not render the Carbon's snippets ❌
              """)
    }

    func printHelp() {
        print("\(scriptName) --from <playground page> --to <carbon output>")
        print("""

                    from: is the path to playground page. ex. `/home/nef.playground/Pages/Intro.xcplaygroundpage`
                    to: path where Carbon snippets are saved to. ex. `/home`

             """)
    }
}
