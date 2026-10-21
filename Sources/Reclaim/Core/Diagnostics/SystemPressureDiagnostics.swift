// SystemPressureDiagnostics.swift
// Reclaim Core — System Diagnostics & Pressure Insights
//
// Pure Swift engine providing real-time diagnosis of Unified Memory pressure,
// APFS swap load, resident AI model allocations, and process-level slowness insights.

import Foundation
import Darwin

// MARK: - Protocol

public protocol SystemPressureDiagnosticsProtocol: Sendable {
    func readMemoryMetrics() -> MemoryMetrics
    func inspectProcesses(limit: Int) async -> [ProcessInsight]
    func inspectLoadedOllamaModels() async -> [(name: String, sizeVRAM: Int64)]
    func generateReport() async -> PressureReport
}

// MARK: - Diagnostic Engine Implementation

public final class SystemPressureDiagnostics: SystemPressureDiagnosticsProtocol, @unchecked Sendable {
    public init() {}

    // MARK: - Mach VM & Swap Metrics

    public func readMemoryMetrics() -> MemoryMetrics {
        let totalRAM = Int64(ProcessInfo.processInfo.physicalMemory)
        var pageSize: vm_size_t = 16384
        _ = host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let activeBytes: Int64
        let inactiveBytes: Int64
        let wiredBytes: Int64
        let freeBytes: Int64
        let compressedBytes: Int64

        if kerr == KERN_SUCCESS {
            let pSize = Int64(pageSize)
            activeBytes = Int64(vmStats.active_count) * pSize
            inactiveBytes = Int64(vmStats.inactive_count) * pSize
            wiredBytes = Int64(vmStats.wire_count) * pSize
            freeBytes = Int64(vmStats.free_count) * pSize
            compressedBytes = Int64(vmStats.compressor_page_count) * pSize
        } else {
            // Fallback estimation
            activeBytes = totalRAM / 3
            inactiveBytes = totalRAM / 4
            wiredBytes = totalRAM / 4
            freeBytes = totalRAM / 6
            compressedBytes = 0
        }

        // Swap stats via Darwin sysctl
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapErr = sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
        let swapUsed: Int64 = (swapErr == 0) ? Int64(swapUsage.xsu_used) : 0
        let swapTotal: Int64 = (swapErr == 0) ? Int64(swapUsage.xsu_total) : 0

        let usedBytes = wiredBytes + activeBytes + compressedBytes
        let pressureRatio = totalRAM > 0 ? Double(usedBytes) / Double(totalRAM) : 0.0

        return MemoryMetrics(
            totalPhysicalRAM: totalRAM,
            usedRAM: usedBytes,
            freeRAM: freeBytes,
            activeRAM: activeBytes,
            inactiveRAM: inactiveBytes,
            wiredRAM: wiredBytes,
            compressedRAM: compressedBytes,
            swapUsed: swapUsed,
            swapTotal: swapTotal,
            pressurePercentage: min(max(pressureRatio * 100.0, 0.0), 100.0)
        )
    }

    // MARK: - Process Inspection

    public func inspectProcesses(limit: Int = 15) async -> [ProcessInsight] {
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-eo", "pid,ppid,%cpu,rss,comm"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                guard let output = String(data: data, encoding: .utf8) else { return [] }

                var insights: [ProcessInsight] = []
                let lines = output.components(separatedBy: "\n")

                for line in lines.dropFirst() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }

                    let tokens = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
                    guard tokens.count >= 5,
                          let pid = Int32(tokens[0]),
                          let ppid = Int32(tokens[1]),
                          let cpu = Double(tokens[2]),
                          let rssKB = Int64(tokens[3]) else { continue }

                    let comm = String(tokens[4])
                    let memoryBytes = rssKB * 1024
                    guard memoryBytes > 100 * 1024 * 1024 else { continue } // Filter < 100MB

                    let baseName = URL(fileURLWithPath: comm).lastPathComponent
                    let category = self.categorizeProcess(comm: comm, baseName: baseName, ppid: ppid)

                    let insight = ProcessInsight(
                        pid: pid,
                        name: self.readableProcessName(baseName: baseName, comm: comm),
                        memoryBytes: memoryBytes,
                        category: category,
                        cpuPercent: cpu,
                        elapsedTimeString: "\(Int(cpu))% CPU",
                        details: comm
                    )
                    insights.append(insight)
                }

                // Sort descending by memory usage
                insights.sort { $0.memoryBytes > $1.memoryBytes }
                return Array(insights.prefix(limit))
            } catch {
                return []
            }
        }.value
    }

    // MARK: - Ollama Model Check

    public func inspectLoadedOllamaModels() async -> [(name: String, sizeVRAM: Int64)] {
        guard let url = URL(string: "http://127.0.0.1:11434/api/ps") else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5 // Non-blocking fast check
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }

            struct OllamaPSResponse: Codable {
                struct ModelItem: Codable {
                    let name: String
                    let size_vram: Int64?
                    let size: Int64?
                }
                let models: [ModelItem]?
            }

            let decoded = try JSONDecoder().decode(OllamaPSResponse.self, from: data)
            return decoded.models?.map { ($0.name, $0.size_vram ?? $0.size ?? 0) } ?? []
        } catch {
            return [] // Ollama not running or port blocked
        }
    }

    // MARK: - Comprehensive Report Generation

    public func generateReport() async -> PressureReport {
        let metrics = readMemoryMetrics()
        let processes = await inspectProcesses(limit: 15)
        let ollamaModels = await inspectLoadedOllamaModels()

        // Determine Level
        let level: MemoryPressureLevel
        if metrics.swapUsed > (4 * 1024 * 1024 * 1024) || metrics.pressurePercentage > 92.0 {
            level = .critical
        } else if metrics.swapUsed > (1024 * 1024 * 1024) || metrics.pressurePercentage > 80.0 {
            level = .warning
        } else {
            level = .normal
        }

        var rootCauses: [RootCauseInsight] = []
        var recommendations: [PressureRecommendation] = []

        // 1. Swap thrashing check
        if metrics.swapUsed > (512 * 1024 * 1024) {
            rootCauses.append(RootCauseInsight(
                severity: metrics.swapUsed > (2 * 1024 * 1024 * 1024) ? .critical : .warning,
                title: "APFS Swap Paging (\(metrics.formattedSwapUsed) on SSD)",
                explanation: "macOS is actively swapping RAM pages to SSD flash memory because unified memory is saturated. Paging causes disk I/O contention, micro-stutters, and app launch delays.",
                impact: "SSD I/O bottleneck; UI frame drops"
            ))
        }

        // 2. High memory compression
        if metrics.compressedRAM > (3 * 1024 * 1024 * 1024) {
            rootCauses.append(RootCauseInsight(
                severity: .warning,
                title: "High Memory Compression (\(metrics.formattedCompressedRAM))",
                explanation: "The macOS kernel compressor is under sustained load packing inactive memory blocks. Decompressing pages on-the-fly adds CPU latency.",
                impact: "CPU compression overhead"
            ))
        }

        // 3. AI / LLM models resident in RAM
        if !ollamaModels.isEmpty {
            for model in ollamaModels {
                let formattedSize = ByteCountFormatter.string(fromByteCount: model.sizeVRAM, countStyle: .memory)
                rootCauses.append(RootCauseInsight(
                    severity: .warning,
                    title: "Ollama Model in Unified VRAM: \(model.name) (\(formattedSize))",
                    explanation: "Model tensors remain mapped in unified memory so subsequent queries run fast, but this reduces available RAM for apps and OS page caches.",
                    impact: "Locks \(formattedSize) physical unified RAM",
                    targetProcessOrModel: model.name
                ))

                recommendations.append(PressureRecommendation(
                    title: "Unload \(model.name) from VRAM",
                    description: "Free \(formattedSize) of unified memory without stopping the Ollama daemon.",
                    actionKind: .unloadLLM,
                    estimatedReclaimBytes: model.sizeVRAM,
                    commandOrAction: "ollama stop \(model.name)"
                ))
            }
        }

        // Check for other LLM / AI processes from ps
        let llmProcesses = processes.filter { $0.category == .llmRuntime }
        for proc in llmProcesses where ollamaModels.isEmpty {
            rootCauses.append(RootCauseInsight(
                severity: .warning,
                title: "\(proc.name) Running in Unified Memory (\(proc.formattedMemory))",
                explanation: "AI runtime process is consuming large unified memory buffers.",
                impact: "Occupies \(proc.formattedMemory) RAM",
                targetProcessOrModel: proc.name
            ))
        }

        // 4. Developer toolchains / IDEs
        let devProcesses = processes.filter { $0.category == .devTooling && $0.memoryBytes > 500 * 1024 * 1024 }
        if let topDev = devProcesses.first {
            rootCauses.append(RootCauseInsight(
                severity: .normal,
                title: "Developer Toolchain: \(topDev.name) (\(topDev.formattedMemory))",
                explanation: "IDE, container engine, or build toolchain is maintaining active workspace indexes and heap memory.",
                impact: "Active developer workspace",
                targetProcessOrModel: topDev.name
            ))
        }

        // 5. Zombie or idle background workers
        let zombieWorkers = processes.filter { $0.category == .zombieWorker && $0.memoryBytes > 300 * 1024 * 1024 }
        if !zombieWorkers.isEmpty {
            let totalZombieMemory = zombieWorkers.reduce(0) { $0 + $1.memoryBytes }
            let count = zombieWorkers.count
            rootCauses.append(RootCauseInsight(
                severity: .warning,
                title: "\(count) Detached Background Worker(s) (\(ByteCountFormatter.string(fromByteCount: totalZombieMemory, countStyle: .memory)))",
                explanation: "Python or Node worker processes launched by scripts or extensions are lingering in the background.",
                impact: "Unused resident memory",
                targetProcessOrModel: zombieWorkers.map { $0.name }.joined(separator: ", ")
            ))

            recommendations.append(PressureRecommendation(
                title: "Review Idle Background Workers",
                description: "Inspect \(count) background workers holding \(ByteCountFormatter.string(fromByteCount: totalZombieMemory, countStyle: .memory)).",
                actionKind: .reviewProcess,
                estimatedReclaimBytes: totalZombieMemory
            ))
        }

        // Standard Safe Recommendations
        if metrics.inactiveRAM > (1024 * 1024 * 1024) {
            recommendations.append(PressureRecommendation(
                title: "Purge Inactive File Buffers",
                description: "Instruct macOS to evict stale file caches and inactive buffers back into the free memory pool.",
                actionKind: .purgeRAM,
                estimatedReclaimBytes: metrics.inactiveRAM,
                commandOrAction: "purge"
            ))
        }

        recommendations.append(PressureRecommendation(
            title: "Clean Stale Caches in Reclaim",
            description: "Run Smart Scan to remove build artifacts, package manager caches, and log files.",
            actionKind: .cleanCaches,
            estimatedReclaimBytes: 2 * 1024 * 1024 * 1024
        ))

        // Summary Text
        let summary: String
        switch level {
        case .normal:
            summary = "Your system has adequate unified memory headroom. Memory pressure is \(Int(metrics.pressurePercentage))%."
        case .warning:
            summary = "Elevated memory pressure (\(Int(metrics.pressurePercentage))%) detected with \(metrics.formattedSwapUsed) swapped to SSD. AI model weights and heavy developer tools are constraining available RAM."
        case .critical:
            summary = "Critical swap thrashing detected (\(metrics.formattedSwapUsed) on SSD). System responsiveness is severely degraded. Recommended to unload idle LLM models or purge inactive buffers."
        }

        return PressureReport(
            timestamp: Date(),
            pressureLevel: level,
            metrics: metrics,
            summary: summary,
            rootCauses: rootCauses,
            topConsumers: processes,
            recommendations: recommendations
        )
    }

    // MARK: - Process Categorization Helpers

    private func categorizeProcess(comm: String, baseName: String, ppid: Int32) -> ProcessCategory {
        let lower = comm.lowercased()

        if lower.contains("ollama") || lower.contains("llama") || lower.contains("lm studio") ||
           lower.contains("vllm") || lower.contains("torch") || lower.contains("mlx") {
            return .llmRuntime
        }

        if lower.contains("docker") || lower.contains("colima") || lower.contains("idea") ||
           lower.contains("code") || lower.contains("cursor") || lower.contains("xcode") ||
           lower.contains("cargo") || lower.contains("rust-analyzer") || lower.contains("sourcekit") ||
           lower.contains("gradle") || lower.contains("java") {
            return .devTooling
        }

        if (lower.contains("python") || lower.contains("node") || lower.contains("ruby")) && (ppid == 1) {
            return .zombieWorker
        }

        if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") ||
           lower.contains("slack") || lower.contains("discord") || lower.contains("electron") {
            return .browserElectron
        }

        return .system
    }

    private func readableProcessName(baseName: String, comm: String) -> String {
        if comm.contains("Google Chrome") { return "Google Chrome" }
        if comm.contains("IntelliJ IDEA") { return "IntelliJ IDEA" }
        if comm.contains("Antigravity") { return "Antigravity IDE" }
        if comm.contains("Visual Studio Code") || comm.contains("Code") { return "VS Code" }
        if comm.contains("Cursor") { return "Cursor" }
        if comm.contains("Docker") { return "Docker Desktop" }
        if comm.contains("ollama") { return "Ollama Engine" }
        return baseName
    }
}
