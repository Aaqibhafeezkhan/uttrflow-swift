// Fetches a model's assets at install time, the module's only network call.
internal import Foundation
internal import UttrflowCore
private import CryptoKit

// The one file in UttrflowSpeech allowed to open a connection; Scripts/offline_audit.sh names it.

/// Fetches every file in a model's folder at install time, pinned to a commit and checked file by file.
func downloadWeights(
    for model: SpeechModel, into destination: URL,
    onProgress: @escaping @Sendable (Double) -> Void
) async throws {
    let total = max(model.weightFiles.values.reduce(Int64(0)) { $0 + $1.bytes }, 1)
    var completed = try completedPinnedWeightBytes(for: model, in: destination)
    onProgress(Double(completed) / Double(total))

    guard !model.weightFiles.isEmpty else {
        throw SpeechModelFetchFailure(reason: "\(model.variant) has no recorded files")
    }
    for (name, expected) in model.weightFiles.sorted(by: { $0.key < $1.key }) {
        let file = destination.appending(path: name)
        if try verified(file: file, expected: expected) {
            continue
        }

        let completedBeforeFile = completed
        try await fetchPinnedFile(
            repository: model.weightsRepository,
            revision: model.weightsRevision,
            path: "\(model.variant)/\(name)",
            destination: file,
            expected: expected
        ) { bytes in
            onProgress(Double(completedBeforeFile + bytes) / Double(total))
        }
        completed += expected.bytes
        onProgress(Double(completed) / Double(total))
    }
}

/// Fetches a model's tokenizer at install time, so WhisperKit never reaches for one while decoding.
func downloadTokenizer(for model: SpeechModel, into destination: URL) async throws {
    for name in TokenizerAssets.fileNames {
        guard
            let url = URL(
                string:
                    "https://huggingface.co/\(model.tokenizerRepository)/resolve/\(model.tokenizerRevision)/\(name)"
            )
        else {
            throw TokenizerFetchFailure(reason: "\(model.tokenizerRepository) is not an address")
        }

        // No token and no endpoint of anybody's choosing: this fetches a public file and says who nobody is.
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw TokenizerFetchFailure(
                reason: "\(model.tokenizerRepository) answered \(status) for \(name)")
        }

        // A pinned commit says which file to fetch; only the digest says it is the file that was pinned.
        guard let expected = model.tokenizerDigests[name] else {
            throw TokenizerFetchFailure(reason: "\(name) has no recorded digest to check against")
        }
        let found = hexDigest(SHA256.hash(data: data))
        guard found == expected else {
            throw TokenizerFetchFailure(
                reason: "\(name) from \(model.tokenizerRepository) hashed \(found), not \(expected)")
        }

        // Atomic, so a dropped connection cannot leave a truncated file that passes as a tokenizer.
        try PrivateFile.write(data, to: destination.appending(path: name))
    }
}

private func completedPinnedWeightBytes(for model: SpeechModel, in destination: URL) throws -> Int64 {
    var completed: Int64 = 0
    for (name, expected) in model.weightFiles {
        if try verified(file: destination.appending(path: name), expected: expected) {
            completed += expected.bytes
        }
    }
    return completed
}

private func verified(file: URL, expected: SpeechModelFile) throws -> Bool {
    let values = try? file.resourceValues(forKeys: [.fileSizeKey])
    guard Int64(values?.fileSize ?? -1) == expected.bytes else { return false }
    return try sha256(of: file) == expected.sha256
}

private func fetchPinnedFile(
    repository: String,
    revision: String,
    path: String,
    destination: URL,
    expected: SpeechModelFile,
    onProgress: @escaping @Sendable (Int64) -> Void
) async throws {
    guard let url = URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(path)") else {
        throw SpeechModelFetchFailure(reason: "\(repository) is not an address")
    }

    let (downloaded, response) = try await URLSession.shared.download(from: url)
    defer { try? FileManager.default.removeItem(at: downloaded) }
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        throw SpeechModelFetchFailure(reason: "\(repository) answered \(status) for \(path)")
    }

    let values = try downloaded.resourceValues(forKeys: [.fileSizeKey])
    let received = Int64(values.fileSize ?? -1)
    guard received == expected.bytes else {
        throw SpeechModelFetchFailure(reason: "\(path) was \(received) bytes, not \(expected.bytes)")
    }
    let found = try sha256(of: downloaded)
    guard found == expected.sha256 else {
        throw SpeechModelFetchFailure(reason: "\(path) hashed \(found), not \(expected.sha256)")
    }

    let fileManager = FileManager.default
    let parent = destination.deletingLastPathComponent()
    try PrivateFile.makeDirectory(at: parent)
    let temporary = parent.appending(path: ".\(destination.lastPathComponent).\(UUID().uuidString).download")
    if fileManager.fileExists(atPath: temporary.path) {
        try fileManager.removeItem(at: temporary)
    }
    defer { try? fileManager.removeItem(at: temporary) }
    try fileManager.moveItem(at: downloaded, to: temporary)
    try PrivateFile.tighten(at: temporary)

    if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
    }
    try fileManager.moveItem(at: temporary, to: destination)
    try PrivateFile.tighten(at: destination)
    onProgress(expected.bytes)
}

private func sha256(of file: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: file)
    defer { try? handle.close() }
    var hasher = SHA256()
    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
        hasher.update(data: chunk)
    }
    return hexDigest(hasher.finalize())
}

private func hexDigest<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
    digest.map { String(format: "%02x", $0) }.joined()
}

/// Why a tokenizer could not be fetched; a sentence for the log, since nothing branches on it.
struct TokenizerFetchFailure: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}

/// Why a speech model asset could not be fetched; a sentence for the log.
struct SpeechModelFetchFailure: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}
