// NewAnalyzerTests.swift
// ReclaimTests/Unit/Analyzers
//
// TDD unit tests for: LLMAnalyzer, MLFrameworksAnalyzer, PythonEnvAnalyzer,
// RubyAnalyzer, JVMAnalyzer, BackupAnalyzer, and GenericCategorizer new categories.
//
// All tests use fixture paths — never real home directories.
// No deletion APIs are called.

import Foundation
@testable import Reclaim

func runNewAnalyzerTests(_ r: TestRunner) async {
    print("\nNew Analyzers (LLM / ML / Python / Ruby / JVM / Backups)")

    let context = AnalysisContext(rootURL: URL(fileURLWithPath: "/tmp/fixtures"))

    // ─────────────────────────────────────────────────────────────
    // MARK: LLMAnalyzer
    // ─────────────────────────────────────────────────────────────

    r.test("LLMAnalyzer: canAnalyze claims Ollama model path") {
        let analyzer = LLMAnalyzer()
        let item = StorageItem(path: "/Users/test/.ollama/models/llama3/blob/sha256-abc", logicalSize: 4_000_000_000, allocatedSize: 4_000_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    r.test("LLMAnalyzer: canAnalyze claims Hugging Face hub path") {
        let analyzer = LLMAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/huggingface/hub/models--meta-llama", logicalSize: 7_000_000_000, allocatedSize: 7_000_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    r.test("LLMAnalyzer: canAnalyze claims large .gguf file") {
        let analyzer = LLMAnalyzer()
        let item = StorageItem(path: "/Users/test/models/llama-3-8b-Q4_K_M.gguf", logicalSize: 4_500_000_000, allocatedSize: 4_500_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    await r.asyncTest("LLMAnalyzer: Ollama model gets LOW risk and is cleanup candidate") {
        let analyzer = LLMAnalyzer()
        let item = StorageItem(path: "/Users/test/.ollama/models/manifests/registry.ollama.ai/library/llama3", logicalSize: 4_000_000_000, allocatedSize: 4_000_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .low)
        try r.expectEqual(result.isCleanupCandidate, true)
        try r.expectEqual(result.item.category, .llm)
    }

    await r.asyncTest("LLMAnalyzer: HuggingFace hub cache gets SAFE risk") {
        let analyzer = LLMAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/huggingface/hub/models--bert-base-uncased", logicalSize: 400_000_000, allocatedSize: 400_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .safe)
        try r.expectEqual(result.isCleanupCandidate, true)
    }

    await r.asyncTest("LLMAnalyzer: User checkpoint path gets HIGH risk and is NOT cleanup candidate") {
        let analyzer = LLMAnalyzer()
        let item = StorageItem(path: "/Users/test/projects/my-finetune/checkpoints/step-10000", logicalSize: 14_000_000_000, allocatedSize: 14_000_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .high)
        try r.expectEqual(result.isCleanupCandidate, false)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: MLFrameworksAnalyzer
    // ─────────────────────────────────────────────────────────────

    r.test("MLFrameworksAnalyzer: canAnalyze claims PyTorch cache") {
        let analyzer = MLFrameworksAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/torch/hub/checkpoints/resnet50.pth", logicalSize: 100_000_000, allocatedSize: 100_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    r.test("MLFrameworksAnalyzer: canAnalyze claims Jupyter checkpoint") {
        let analyzer = MLFrameworksAnalyzer()
        let item = StorageItem(path: "/Users/test/notebooks/.ipynb_checkpoints/analysis-checkpoint.ipynb", logicalSize: 500_000, allocatedSize: 500_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    await r.asyncTest("MLFrameworksAnalyzer: PyTorch cache gets SAFE risk") {
        let analyzer = MLFrameworksAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/torch/hub/checkpoints/bert.pth", logicalSize: 400_000_000, allocatedSize: 400_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .safe)
        try r.expectEqual(result.item.category, .mlFrameworks)
    }

    await r.asyncTest("MLFrameworksAnalyzer: Jupyter checkpoint gets LOW risk") {
        let analyzer = MLFrameworksAnalyzer()
        let item = StorageItem(path: "/Users/test/.ipynb_checkpoints/notebook-checkpoint.ipynb", logicalSize: 200_000, allocatedSize: 200_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .low)
        try r.expectEqual(result.isCleanupCandidate, true)
    }

    await r.asyncTest("MLFrameworksAnalyzer: MLflow run is NOT cleanup candidate") {
        let analyzer = MLFrameworksAnalyzer()
        let item = StorageItem(path: "/Users/test/project/mlruns/0/abc123/artifacts", logicalSize: 2_000_000_000, allocatedSize: 2_000_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.isCleanupCandidate, false)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: PythonEnvAnalyzer
    // ─────────────────────────────────────────────────────────────

    r.test("PythonEnvAnalyzer: canAnalyze claims pip cache") {
        let analyzer = PythonEnvAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/pip/wheels/numpy-1.26", logicalSize: 50_000_000, allocatedSize: 50_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    r.test("PythonEnvAnalyzer: canAnalyze claims pyenv version") {
        let analyzer = PythonEnvAnalyzer()
        let item = StorageItem(path: "/Users/test/.pyenv/versions/3.11.0/lib", logicalSize: 200_000_000, allocatedSize: 200_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    r.test("PythonEnvAnalyzer: canAnalyze claims __pycache__") {
        let analyzer = PythonEnvAnalyzer()
        let item = StorageItem(path: "/Users/test/project/src/__pycache__/utils.cpython-311.pyc", logicalSize: 4_096, allocatedSize: 8_192)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    await r.asyncTest("PythonEnvAnalyzer: pip cache gets SAFE risk") {
        let analyzer = PythonEnvAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/pip/wheels/numpy-1.26-cp311.whl", logicalSize: 50_000_000, allocatedSize: 50_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .safe)
        try r.expectEqual(result.item.category, .pythonEnv)
    }

    await r.asyncTest("PythonEnvAnalyzer: conda env gets LOW risk") {
        let analyzer = PythonEnvAnalyzer()
        let item = StorageItem(path: "/Users/test/miniconda3/envs/myproject/lib", logicalSize: 500_000_000, allocatedSize: 500_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .low)
    }

    await r.asyncTest("PythonEnvAnalyzer: __pycache__ gets SAFE risk") {
        let analyzer = PythonEnvAnalyzer()
        let item = StorageItem(path: "/Users/test/app/__pycache__/main.cpython-311.pyc", logicalSize: 4_096, allocatedSize: 4_096)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .safe)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: RubyAnalyzer
    // ─────────────────────────────────────────────────────────────

    r.test("RubyAnalyzer: canAnalyze claims rbenv version path") {
        let analyzer = RubyAnalyzer()
        let item = StorageItem(path: "/Users/test/.rbenv/versions/3.2.0/lib", logicalSize: 100_000_000, allocatedSize: 100_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    await r.asyncTest("RubyAnalyzer: gem cache gets SAFE risk") {
        let analyzer = RubyAnalyzer()
        let item = StorageItem(path: "/Users/test/.rbenv/versions/3.2.0/lib/ruby/gems/3.2.0/cache/rails-7.1.gem", logicalSize: 10_000_000, allocatedSize: 10_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .safe)
        try r.expectEqual(result.item.category, .ruby)
    }

    await r.asyncTest("RubyAnalyzer: rbenv version gets LOW risk") {
        let analyzer = RubyAnalyzer()
        let item = StorageItem(path: "/Users/test/.rbenv/versions/2.7.0/bin/ruby", logicalSize: 50_000_000, allocatedSize: 50_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .low)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: JVMAnalyzer
    // ─────────────────────────────────────────────────────────────

    r.test("JVMAnalyzer: canAnalyze claims Coursier cache") {
        let analyzer = JVMAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/coursier/v1/https/repo1.maven.org", logicalSize: 500_000_000, allocatedSize: 500_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    r.test("JVMAnalyzer: canAnalyze claims Kotlin/Native konan path") {
        let analyzer = JVMAnalyzer()
        let item = StorageItem(path: "/Users/test/.konan/kotlin-native-prebuilt-macos-aarch64-1.9.0", logicalSize: 800_000_000, allocatedSize: 800_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    await r.asyncTest("JVMAnalyzer: Coursier cache gets SAFE risk") {
        let analyzer = JVMAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/coursier/v1/https/repo1.maven.org/org/scala-lang", logicalSize: 300_000_000, allocatedSize: 300_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .safe)
        try r.expectEqual(result.item.category, .jvm)
    }

    await r.asyncTest("JVMAnalyzer: Kotlin Native konan gets SAFE risk") {
        let analyzer = JVMAnalyzer()
        let item = StorageItem(path: "/Users/test/.konan/kotlin-native-prebuilt-macos-aarch64-1.9.0/bin", logicalSize: 800_000_000, allocatedSize: 800_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .safe)
    }

    await r.asyncTest("JVMAnalyzer: JDK installation gets LOW risk") {
        let analyzer = JVMAnalyzer()
        let item = StorageItem(path: "/Library/Java/JavaVirtualMachines/jdk-11.0.0.jdk/Contents/Home/bin/java", logicalSize: 200_000_000, allocatedSize: 200_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .low)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: BackupAnalyzer
    // ─────────────────────────────────────────────────────────────

    r.test("BackupAnalyzer: canAnalyze claims MobileSync backup path") {
        let analyzer = BackupAnalyzer()
        let item = StorageItem(path: "/Users/test/Library/Application Support/MobileSync/Backup/abc123", logicalSize: 40_000_000_000, allocatedSize: 40_000_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    r.test("BackupAnalyzer: canAnalyze claims large .dmg file") {
        let analyzer = BackupAnalyzer()
        let item = StorageItem(path: "/Users/test/Downloads/Xcode_15.dmg", logicalSize: 7_000_000_000, allocatedSize: 7_000_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
    }

    await r.asyncTest("BackupAnalyzer: iPhone backup gets HIGH risk and is NOT candidate") {
        let analyzer = BackupAnalyzer()
        let item = StorageItem(path: "/Users/test/Library/Application Support/MobileSync/Backup/abc-def-ghi", logicalSize: 40_000_000_000, allocatedSize: 40_000_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .high)
        try r.expectEqual(result.isCleanupCandidate, false)
        try r.expectEqual(result.item.category, .backups)
    }

    await r.asyncTest("BackupAnalyzer: .dmg disk image gets MEDIUM risk and IS candidate") {
        let analyzer = BackupAnalyzer()
        let item = StorageItem(path: "/Users/test/Downloads/Xcode_15.1.dmg", logicalSize: 7_000_000_000, allocatedSize: 7_000_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .medium)
        try r.expectEqual(result.isCleanupCandidate, true)
    }

    await r.asyncTest("BackupAnalyzer: .pkg installer gets LOW risk and IS candidate") {
        let analyzer = BackupAnalyzer()
        let item = StorageItem(path: "/Users/test/Downloads/VSCode.pkg", logicalSize: 400_000_000, allocatedSize: 400_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .low)
        try r.expectEqual(result.isCleanupCandidate, true)
    }

    await r.asyncTest("BackupAnalyzer: .xip Xcode archive gets LOW risk") {
        let analyzer = BackupAnalyzer()
        let item = StorageItem(path: "/Users/test/Downloads/Xcode_15.2.xip", logicalSize: 10_000_000_000, allocatedSize: 10_000_000_000)
        let result = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(result.item.risk, .low)
        try r.expectEqual(result.isCleanupCandidate, true)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: GenericCategorizer — new categories
    // ─────────────────────────────────────────────────────────────

    r.test("GenericCategorizer: categorizes Ollama path as .llm") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.ollama/models/blobs/sha256-abc"), .llm)
    }

    r.test("GenericCategorizer: categorizes HuggingFace hub as .llm") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.cache/huggingface/hub/models--bert"), .llm)
    }

    r.test("GenericCategorizer: categorizes HuggingFace datasets as .mlFrameworks") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.cache/huggingface/datasets/squad"), .mlFrameworks)
    }

    r.test("GenericCategorizer: categorizes PyTorch cache as .mlFrameworks") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.cache/torch/hub/checkpoints"), .mlFrameworks)
    }

    r.test("GenericCategorizer: categorizes pyenv path as .pythonEnv") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.pyenv/versions/3.11.0/lib"), .pythonEnv)
    }

    r.test("GenericCategorizer: categorizes conda pkgs as .pythonEnv") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/miniconda3/pkgs/numpy-1.26"), .pythonEnv)
    }

    r.test("GenericCategorizer: categorizes rbenv as .ruby") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.rbenv/versions/3.2.0/bin/ruby"), .ruby)
    }

    r.test("GenericCategorizer: categorizes Coursier cache as .jvm") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.cache/coursier/v1/https/repo1.maven.org"), .jvm)
    }

    r.test("GenericCategorizer: categorizes Kotlin/Native as .jvm") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.konan/kotlin-native-prebuilt-macos"), .jvm)
    }

    r.test("GenericCategorizer: categorizes MobileSync backup as .backups") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/Library/Application Support/MobileSync/Backup/abc"), .backups)
    }

    r.test("GenericCategorizer: categorizes Playwright and Puppeteer as .node") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/Library/Caches/ms-playwright/chromium-1097"), .node)
        try r.expectEqual(cat.categorize(path: "/Users/test/.cache/puppeteer/chrome"), .node)
    }

    r.test("GenericCategorizer: categorizes uv and poetry as .pythonEnv") {
        let cat = GenericCategorizer()
        try r.expectEqual(cat.categorize(path: "/Users/test/.cache/uv/wheels"), .pythonEnv)
        try r.expectEqual(cat.categorize(path: "/Users/test/.cache/pypoetry/artifacts"), .pythonEnv)
    }

    await r.asyncTest("NodeAnalyzer: claims and analyzes Playwright binary cache") {
        let analyzer = NodeAnalyzer()
        let item = StorageItem(path: "/Users/test/Library/Caches/ms-playwright", logicalSize: 500_000_000, allocatedSize: 500_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
        let res = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(res.item.risk, .safe)
        try r.expectEqual(res.isCleanupCandidate, true)
    }

    await r.asyncTest("PythonEnvAnalyzer: claims and analyzes Astral uv cache") {
        let analyzer = PythonEnvAnalyzer()
        let item = StorageItem(path: "/Users/test/.cache/uv", logicalSize: 250_000_000, allocatedSize: 250_000_000)
        try r.expectEqual(analyzer.canAnalyze(item), true)
        let res = try await analyzer.analyze(item: item, context: context)
        try r.expectEqual(res.item.risk, .safe)
        try r.expectEqual(res.isCleanupCandidate, true)
    }
}
