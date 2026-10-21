import Foundation
@testable import Reclaim

func runFileScannerTests(_ r: TestRunner) async {
    print("\nFileScanner")

    let fixturesURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Tests/Fixtures/scanner")
    
    await r.asyncTest("Scanner yields items via AsyncStream") {
        let scanner = FileScanner(rootURL: fixturesURL)
        var count = 0
        for await _ in scanner.scan() {
            count += 1
        }
        try r.expect(count >= 2, "Expected at least 2 files in scanner fixture")
    }
}
