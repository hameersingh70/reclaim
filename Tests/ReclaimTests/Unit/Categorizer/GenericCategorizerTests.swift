// GenericCategorizerTests.swift
// ReclaimTests

import Foundation
@testable import Reclaim

func runGenericCategorizerTests(_ r: TestRunner) {
    print("\nGenericCategorizer")
    
    let categorizer = GenericCategorizer()
    
    r.test("Categorizes gradle path") {
        let item = StorageItem(path: "/Users/test/.gradle/caches/something", logicalSize: 0, allocatedSize: 0)
        let cat = categorizer.categorize(item)
        try r.expectEqual(cat, .gradle)
    }
    
    r.test("Categorizes node path") {
        let item = StorageItem(path: "/Users/test/project/node_modules/pkg", logicalSize: 0, allocatedSize: 0)
        let cat = categorizer.categorize(item)
        try r.expectEqual(cat, .node)
    }

    r.test("Categorizes documents path") {
        let item = StorageItem(path: "/Users/test/Documents/file.txt", logicalSize: 0, allocatedSize: 0)
        let cat = categorizer.categorize(item)
        try r.expectEqual(cat, .documents)
    }
    
    r.test("Categorizes unknown path as generic") {
        let item = StorageItem(path: "/Users/test/RandomFolder/file.txt", logicalSize: 0, allocatedSize: 0)
        let cat = categorizer.categorize(item)
        try r.expectEqual(cat, .generic)
    }
}
