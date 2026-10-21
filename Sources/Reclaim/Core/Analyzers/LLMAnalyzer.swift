// LLMAnalyzer.swift
// Core/Analyzers
//
// Classifies local LLM model stores: Ollama, LM Studio, Jan, GPT4All,
// Hugging Face Hub, GGUF / GGML / Safetensors model files.
//
// Risk philosophy:
//   - Hub-downloaded model weights: SAFE/LOW — re-downloadable
//   - User fine-tuned checkpoints: HIGH — irreplaceable compute cost
//   - Active model server files: LOW — re-pullable

import Foundation

public struct LLMAnalyzer: StorageAnalyzer {

    public let id = "com.reclaim.llm"
    public let displayName = "LLM Models"

    private static let weightExtensions: Set<String> = [
        "gguf", "ggml", "bin", "pt", "pth", "ckpt", "safetensors", "llamafile"
    ]

    private static let llmMarkers: [String] = [
        "/.ollama/models",
        "/lm studio/models",
        "/lmstudio/models",
        "/jan/models",
        "/gpt4all",
        "/.cache/huggingface/hub",
        "/.cache/huggingface/transformers",
        "/huggingface/hub",
        "/.cache/lm_studio",
        "/.local/share/nomic.ai",
        "/llamafile",
        "/.cache/gpt4all",
        "/ollama/models",
    ]

    private static let checkpointMarkers: [String] = [
        "/checkpoints/", "/finetuned/", "/fine-tuned/",
        "/my-model/", "/trained/", "/lora/", "/adapter/",
        "/merged_model/",
    ]

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        if Self.llmMarkers.contains(where: { lower.contains($0) }) { return true }
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()
        return Self.weightExtensions.contains(ext) && item.allocatedSize > 50_000_000
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        let lower = item.path.lowercased()
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()

        var enriched = item
        enriched.category = .llm
        enriched.analyzerID = id

        let isCandidate: Bool
        let note: String

        if Self.checkpointMarkers.contains(where: { lower.contains($0) }) {
            enriched.risk = .high
            enriched.recoverability = .userData
            enriched.whatIsThis = "User fine-tuned model checkpoint — requires manual review"
            enriched.removalConsequence = "May represent hours/days of GPU compute time. Cannot be re-created."
            isCandidate = false
            note = "User fine-tune checkpoint — protected"

        } else if lower.contains("/.ollama/models") {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Ollama model — re-pullable with `ollama pull <model-name>`"
            enriched.recoveryInstruction = "Run: ollama pull <model-name>"
            isCandidate = true
            note = "Ollama model blob — re-downloadable"

        } else if lower.contains("/lm studio") || lower.contains("/lmstudio") {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "LM Studio model — re-downloadable from model hub"
            isCandidate = true
            note = "LM Studio model"

        } else if lower.contains("/jan/models") {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Jan.ai model — re-downloadable from Jan's model hub"
            isCandidate = true
            note = "Jan.ai model"

        } else if lower.contains("/.cache/huggingface") {
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Hugging Face cached model — auto-restored on next `from_pretrained()` call"
            enriched.recoveryInstruction = "Call model.from_pretrained() again — downloads automatically"
            isCandidate = true
            note = "Hugging Face hub cache"

        } else if lower.contains("/gpt4all") || lower.contains("/.cache/gpt4all") {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "GPT4All model — re-downloadable from GPT4All app"
            isCandidate = true
            note = "GPT4All model"

        } else if Self.weightExtensions.contains(ext) {
            enriched.risk = .medium
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Large model weight file (\(ext.uppercased())) — verify source before deleting"
            isCandidate = true
            note = "Large model weight file (\(ext))"

        } else {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "LLM model file — re-downloadable from source"
            isCandidate = true
            note = "LLM model artifact"
        }

        return AnalysisResult(
            item: enriched,
            evidence: [Evidence(kind: .note, description: note)],
            isCleanupCandidate: isCandidate,
            rejectionReason: isCandidate ? nil : "User data — not auto-cleaned"
        )
    }
}
