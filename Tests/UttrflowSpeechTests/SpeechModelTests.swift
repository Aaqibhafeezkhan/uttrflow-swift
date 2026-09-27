// Tests the model catalogue and the engine factory.
import Foundation
import Testing

@testable import UttrflowCore
@testable import UttrflowSpeech

@Suite("SpeechModel")
struct SpeechModelTests {
    @Test("ships a multilingual model by default, because Hindi is required")
    func defaultIsMultilingual() {
        #expect(SpeechModel.default.isMultilingual)
        #expect(SpeechModel.default.supports(.hindi))
        #expect(SpeechModel.default == .largeV3Turbo)
    }

    @Test("lists every model smallest first, so the catalogue reads as a ladder")
    func catalogueIsOrdered() {
        let sizes = SpeechModel.catalogue.map(\.downloadBytes)
        #expect(sizes == sizes.sorted())
        #expect(SpeechModel.catalogue.count == 3)
    }

    @Test("finds a model by its repository identifier")
    func lookup() {
        for model in SpeechModel.catalogue {
            #expect(SpeechModel.named(model.variant) == model)
        }
        #expect(SpeechModel.named("not-a-model") == nil)
    }

    @Test("quotes a real download size for every model")
    func sizesArePlausible() {
        for model in SpeechModel.catalogue {
            #expect(model.downloadBytes > 100_000_000, "\(model.variant) size looks wrong")
            #expect(model.downloadBytes < 2_000_000_000, "\(model.variant) size looks wrong")
        }
    }

    @Test("treats an English-only model as unable to handle other languages")
    func englishOnlySupport() {
        let englishOnly = SpeechModel(
            variant: "x", downloadBytes: 1, isMultilingual: false,
            weightsRepository: "argmaxinc/whisperkit-coreml",
            weightsRevision: String(repeating: "0", count: 40),
            weightFiles: [:],
            tokenizerRepository: "openai/whisper-tiny.en",
            tokenizerRevision: String(repeating: "0", count: 40),
            tokenizerDigests: [:])
        #expect(englishOnly.supports(.english))
        #expect(!englishOnly.supports(.hindi))
    }

    /// A branch name would let a push to the model repository change what a new install runs (#666).
    @Test("every model pins its tokenizer to a commit, not to a branch")
    func everyTokenizerIsPinnedToACommit() {
        for model in SpeechModel.catalogue {
            let revision = model.tokenizerRevision
            #expect(revision.count == 40, "\(model.variant) pins \(revision), which is not a commit")
            #expect(
                revision.allSatisfy { $0.isHexDigit },
                "\(model.variant) pins \(revision), which is not a commit")
        }
    }

    /// A branch name would let a push to the model repository change what a new install runs (#666).
    @Test("every model pins its weights to a commit, not to a branch")
    func everyWeightSetIsPinnedToACommit() {
        for model in SpeechModel.catalogue {
            let revision = model.weightsRevision
            #expect(revision.count == 40, "\(model.variant) pins \(revision), which is not a commit")
            #expect(
                revision.allSatisfy { $0.isHexDigit },
                "\(model.variant) pins \(revision), which is not a commit")
        }
    }

    /// A pinned commit says which files to fetch; only size and digest say the files are the ones pinned.
    @Test("every model records size and digest for every weight file it fetches")
    func everyWeightFileHasSizeAndDigest() {
        for model in SpeechModel.catalogue {
            for name in WeightsAssets.fileNames(of: model) {
                let file = model.weightFiles[name]
                #expect(file != nil, "\(model.variant) records no metadata for \(name)")
                #expect((file?.bytes ?? 0) > 0, "\(model.variant)'s \(name) size is not recorded")
                #expect(file?.sha256.count == 64, "\(model.variant)'s \(name) digest is not a SHA-256")
                #expect(
                    file?.sha256.allSatisfy { $0.isHexDigit } == true,
                    "\(model.variant)'s \(name) digest is not hex")
            }
        }
    }

    /// A manifest that forgets a file installs a folder that cannot load, so it must add up to the whole download.
    @Test("every model's pinned files add up to its whole download")
    func pinnedFilesAreTheWholeDownload() {
        for model in SpeechModel.catalogue {
            let pinned = model.weightFiles.values.reduce(Int64(0)) { $0 + $1.bytes }
            #expect(
                pinned == model.downloadBytes,
                "\(model.variant) pins \(pinned) of \(model.downloadBytes) bytes")
        }
    }

    /// Each compiled bundle is a program plus its weights; without `model.mil` CoreML cannot parse it.
    @Test("every model pins each bundle's program beside its weights")
    func everyBundlePinsItsProgram() {
        for model in SpeechModel.catalogue {
            let bundles = Set(
                model.weightFiles.keys.compactMap { $0.split(separator: "/").first }
                    .filter { $0.hasSuffix(".mlmodelc") })
            #expect(bundles.count >= 3, "\(model.variant) pins \(bundles.count) bundles")
            for bundle in bundles {
                #expect(
                    model.weightFiles["\(bundle)/model.mil"] != nil,
                    "\(model.variant) lacks \(bundle)/model.mil")
                #expect(model.weightFiles["\(bundle)/weights/weight.bin"] != nil)
            }
        }
    }

    /// A pinned commit says which file to fetch; only the digest says the file is the one that was pinned.
    @Test("every model records a digest for every tokenizer file it fetches")
    func everyTokenizerFileHasADigest() {
        for model in SpeechModel.catalogue {
            for name in TokenizerAssets.fileNames {
                let digest = model.tokenizerDigests[name]
                #expect(digest != nil, "\(model.variant) records no digest for \(name)")
                #expect(digest?.count == 64, "\(model.variant)'s \(name) digest is not a SHA-256")
            }
        }
    }

    /// A model naming the wrong tokenizer repository would decode its output into nonsense.
    @Test("names the repository publishing its tokenizer, for every model")
    func everyModelNamesItsTokenizer() {
        for model in SpeechModel.catalogue {
            #expect(
                model.tokenizerRepository.hasPrefix("openai/whisper-"),
                "\(model.variant) names \(model.tokenizerRepository), which is not a Whisper tokenizer"
            )
        }
    }

    @Test("round-trips through Codable so a chosen model survives relaunch")
    func codable() throws {
        let decoded = try JSONDecoder().decode(
            SpeechModel.self, from: JSONEncoder().encode(SpeechModel.default)
        )
        #expect(decoded == .default)
    }
}

@Suite("SpeechEngineFactory")
struct SpeechEngineFactoryTests {
    @Test("builds the recogniser the configuration names", arguments: SpeechEngineKind.allCases)
    func buildsRequestedKind(kind: SpeechEngineKind) {
        let engine = SpeechEngineFactory.make(
            kind: kind, modelFolder: URL(fileURLWithPath: "/tmp/uttrflow-test")
        )
        #expect(engine.kind == kind)
    }
}
