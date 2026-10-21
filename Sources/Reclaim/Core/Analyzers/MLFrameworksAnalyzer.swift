// MLFrameworksAnalyzer.swift
// Core/Analyzers
//
// Classifies ML training framework caches and artifacts:
// PyTorch (torch hub, Triton compiled kernels), TensorFlow/Keras datasets,
// ONNX runtime, CoreML compiled caches, Jupyter checkpoints,
// TensorBoard event logs, MLflow / W&B / DVC artifacts.

import Foundation

public struct MLFrameworksAnalyzer: StorageAnalyzer {

    public let id = "com.reclaim.mlframeworks"
    public let displayName = "ML Frameworks"

    private static let mlMarkers: [String] = [
        "/.cache/torch", "/.triton/cache", "/.triton/autotune",
        "/torch_extensions",
        "/.keras/datasets", "/.keras/models",
        "/.cache/tfhub_modules", "/.tensorflow/models", "/.cache/tensorflow",
        "/library/caches/com.apple.coreml",
        "/.cache/onnxruntime", "/.onnx",
        "/.jupyter/runtime", "/.ipynb_checkpoints",
        "/.local/share/jupyter",
        "/mlruns/", "/wandb/",
        "/.dvc/cache", "/.cache/dvc",
        "/tensorboard/", "/events.out.tfevents",
        "/runs/", "/lightning_logs/", "/ray_results/",
        "/.cache/huggingface/datasets", "/.cache/datasets",
        "/datasets/cache",
    ]

    private static let mlOutputExtensions: Set<String> = [
        "pb", "h5", "hdf5", "tflite", "mlmodel", "mlpackage", "onnx", "tfevents"
    ]

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        if Self.mlMarkers.contains(where: { lower.contains($0) }) { return true }
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()
        return Self.mlOutputExtensions.contains(ext) && item.allocatedSize > 10_000_000
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        let lower = item.path.lowercased()
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()

        var enriched = item
        enriched.category = .mlFrameworks
        enriched.analyzerID = id

        let isCandidate: Bool
        let note: String

        switch true {
        case lower.contains("/.cache/torch") || lower.contains("/.triton"):
            enriched.risk = .safe
            enriched.recoverability = .regeneratable
            enriched.whatIsThis = "PyTorch model hub / Triton kernel cache — recompiled automatically on import"
            isCandidate = true
            note = "PyTorch / Triton cache"

        case lower.contains("/.keras/datasets") || lower.contains("/.cache/tfhub"):
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "TensorFlow / Keras dataset cache — re-downloaded on demand"
            isCandidate = true
            note = "TF/Keras dataset cache"

        case lower.contains("/.ipynb_checkpoints"):
            enriched.risk = .low
            enriched.recoverability = .regeneratable
            enriched.whatIsThis = "Jupyter notebook checkpoint — auto-generated, safe to remove"
            enriched.recoveryInstruction = "Jupyter regenerates checkpoints on save"
            isCandidate = true
            note = "Jupyter checkpoint"

        case lower.contains("/.cache/huggingface/datasets") || lower.contains("/.cache/datasets"):
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Hugging Face dataset cache — auto-reloaded by datasets library"
            isCandidate = true
            note = "HF datasets cache"

        case lower.contains("/.dvc/cache") || lower.contains("/.cache/dvc"):
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "DVC dataset cache — re-fetched from remote with `dvc pull`"
            enriched.recoveryInstruction = "Run: dvc pull"
            isCandidate = true
            note = "DVC cache"

        case lower.contains("/mlruns/"):
            enriched.risk = .medium
            enriched.recoverability = .userData
            enriched.whatIsThis = "MLflow experiment run — contains metrics, params, and artifact links"
            isCandidate = false
            note = "MLflow run — user data"

        case lower.contains("/wandb/"):
            enriched.risk = .medium
            enriched.recoverability = .userData
            enriched.whatIsThis = "Weights & Biases run artifacts — review before deleting"
            isCandidate = false
            note = "W&B artifacts — user data"

        case lower.contains("/tensorboard/") || ext == "tfevents":
            enriched.risk = .low
            enriched.recoverability = .userData
            enriched.whatIsThis = "TensorBoard event log — training metrics visualization data"
            isCandidate = true
            note = "TensorBoard event log"

        case lower.contains("/lightning_logs/") || lower.contains("/ray_results/"):
            enriched.risk = .low
            enriched.recoverability = .userData
            enriched.whatIsThis = "Training run output log — safe to remove old runs"
            isCandidate = true
            note = "Training output logs"

        case ["pb", "h5", "hdf5", "tflite", "mlmodel", "onnx"].contains(ext):
            enriched.risk = .medium
            enriched.recoverability = .userData
            enriched.whatIsThis = "Exported ML model (\(ext.uppercased())) — reproducible from training script"
            isCandidate = false
            note = "Exported model file"

        default:
            enriched.risk = .low
            enriched.recoverability = .regeneratable
            enriched.whatIsThis = "ML framework artifact — likely re-generatable"
            isCandidate = true
            note = "ML artifact"
        }

        return AnalysisResult(
            item: enriched,
            evidence: [Evidence(kind: .note, description: note)],
            isCleanupCandidate: isCandidate,
            rejectionReason: isCandidate ? nil : "User training data — not auto-cleaned"
        )
    }
}
