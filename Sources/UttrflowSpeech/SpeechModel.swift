// The speech models the app can install.
public import UttrflowCore

/// One pinned file that makes up a speech model.
public struct SpeechModelFile: Sendable, Hashable, Codable {
    /// Expected size of the file at the pinned revision.
    public let bytes: Int64
    /// Expected SHA-256 of the file at the pinned revision.
    public let sha256: String

    public init(bytes: Int64, sha256: String) {
        self.bytes = bytes
        self.sha256 = sha256
    }
}

/// A speech-recognition model the app can install; sizes are the real download, shown before the wait.
public struct SpeechModel: Sendable, Hashable, Codable {
    /// Identifier used by the model repository.
    public let variant: String
    /// Total bytes fetched when installing.
    public let downloadBytes: Int64
    /// Whether it recognises languages other than English.
    public let isMultilingual: Bool
    /// The repository publishing the compiled CoreML weights.
    public let weightsRepository: String
    /// The commit the weights are fetched at, so a repository push cannot change a new install.
    public let weightsRevision: String
    /// Every file in the model's folder at that commit, with what it must weigh and hash to.
    public let weightFiles: [String: SpeechModelFile]
    /// The repository publishing the tokenizer, which is OpenAI's while the weights are a CoreML build.
    public let tokenizerRepository: String
    /// The commit the tokenizer is fetched at, so an install a year from now is the install measured here.
    public let tokenizerRevision: String
    /// What each tokenizer file must hash to at that commit, since a pinned name is not a pinned file.
    public let tokenizerDigests: [String: String]

    public init(
        variant: String, downloadBytes: Int64, isMultilingual: Bool,
        weightsRepository: String, weightsRevision: String, weightFiles: [String: SpeechModelFile],
        tokenizerRepository: String,
        tokenizerRevision: String, tokenizerDigests: [String: String]
    ) {
        self.variant = variant
        self.downloadBytes = downloadBytes
        self.isMultilingual = isMultilingual
        self.weightsRepository = weightsRepository
        self.weightsRevision = weightsRevision
        self.weightFiles = weightFiles
        self.tokenizerRepository = tokenizerRepository
        self.tokenizerRevision = tokenizerRevision
        self.tokenizerDigests = tokenizerDigests
    }
}

extension SpeechModel {
    /// What the app installs unless told otherwise: multilingual, and half the decode time of large-v3.
    public static let `default` = largeV3Turbo

    /// A distilled decoder over large-v3's encoder, sharing its vocabulary and therefore its tokenizer.
    public static let largeV3Turbo = SpeechModel(
        variant: "openai_whisper-large-v3-v20240930_turbo_632MB",
        downloadBytes: 645_668_913,
        isMultilingual: true,
        weightsRepository: "argmaxinc/whisperkit-coreml",
        weightsRevision: "0f63a7800b00dd0226abd051b906c246e1907482",
        weightFiles: [
            "AudioEncoder.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "0dd9f529c744ed3c6be67f699588f7aadc4f366b5b7301dc31bd3f199944fbcc"),
            "AudioEncoder.mlmodelc/coremldata.bin": .init(
                bytes: 348,
                sha256: "ffa9eb76e8e9d9be75a4d527e5249e61d67fd43081c5aa110fd24efa6c8c5ea3"),
            "AudioEncoder.mlmodelc/metadata.json": .init(
                bytes: 1974,
                sha256: "2cd0538f90a012de3f07d38669026d527490eff1dcfd2479a81c48206a90f0a2"),
            "AudioEncoder.mlmodelc/model.mil": .init(
                bytes: 7_589_739,
                sha256: "ef5a252831e61bb91d6547fe1add3d0658895b518d47d70004322b40a2192668"),
            "AudioEncoder.mlmodelc/weights/weight.bin": .init(
                bytes: 421_968_768,
                sha256: "e4740fa28ed65907af754af893dfce98473fafb84dd8d718ad346985fe7678c1"),
            "MelSpectrogram.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "c5be419f8622083ac7046306400643539f0e7577c843448c36defc090d41e7ce"),
            "MelSpectrogram.mlmodelc/coremldata.bin": .init(
                bytes: 329,
                sha256: "98efa1e351b759e078c4044668926d32bee886caf7596ae897e08e21da45565a"),
            "MelSpectrogram.mlmodelc/metadata.json": .init(
                bytes: 1850,
                sha256: "2bc552e09a6f124d9e6c178dd1a6979e010206acb26308b2224887c9dcbeb35f"),
            "MelSpectrogram.mlmodelc/model.mil": .init(
                bytes: 10_143,
                sha256: "c270b95b5f81d7f7d0b8a3e8f991d4e5812a37cad29349868a35b91f3a6a4463"),
            "MelSpectrogram.mlmodelc/weights/weight.bin": .init(
                bytes: 373_376,
                sha256: "009d9fb8f6b589accfa08cebf1c712ef07c3405229ce3cfb3a57ee033c9d8a49"),
            "TextDecoder.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "4b5119bdc621c3c494f63846dc3ed43852e88826fc3b6345d42272d4b7e67724"),
            "TextDecoder.mlmodelc/coremldata.bin": .init(
                bytes: 633,
                sha256: "605dad4099a82cf2c7afe93e6d8e322f1c16d4160ab27bd017ec2517b81c1bdd"),
            "TextDecoder.mlmodelc/metadata.json": .init(
                bytes: 4924,
                sha256: "e3ce6d83884552ffcc2c34799e8e1211dcda59f1aaea5a79bf988c6cd16abbf0"),
            "TextDecoder.mlmodelc/model.mil": .init(
                bytes: 217_177,
                sha256: "ebaf8566f367b6465276c3ed57bb99063888fa955b67828585bf19db24c85f56"),
            "TextDecoder.mlmodelc/weights/weight.bin": .init(
                bytes: 203_199_860,
                sha256: "d69700903d518ada33170ab77faaaf464496fb9ff65752c6d5a6109aa2fb02db"),
            "TextDecoderContextPrefill.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "97639d36c7b137ea51c3c39b175911788f4d4a601ab03cd67a4b14164c3145e1"),
            "TextDecoderContextPrefill.mlmodelc/coremldata.bin": .init(
                bytes: 380,
                sha256: "2c159f5c862ec187092ea58e755d8c0b298952e22f3d75da023d7693c1c7389e"),
            "TextDecoderContextPrefill.mlmodelc/metadata.json": .init(
                bytes: 2240,
                sha256: "eb88dc350fa6748a8bc3fa5fb10958152c138752ebbbac1824d2f99b4c9fc068"),
            "TextDecoderContextPrefill.mlmodelc/model.mil": .init(
                bytes: 4092,
                sha256: "990ff5052fd817e28ba7c34d9d06d324c69c7c0630b6eaac9cfdf08329dbcb34"),
            "TextDecoderContextPrefill.mlmodelc/weights/weight.bin": .init(
                bytes: 12_288_192,
                sha256: "1310070082639173e9d81508c5f220692d489e85655aa6883cc1c7506da7fcfd"),
            "config.json": .init(
                bytes: 1149,
                sha256: "f01d83dd891791d6f12421c05d3ed8ebbe70866f10d6c9a7a7e80b558ce5a0f1"),
            "generation_config.json": .init(
                bytes: 2767,
                sha256: "7fbb053a023be11fbeccd8421811610308143daa93d9617c52aab4a0fa1491c6"),
        ],
        tokenizerRepository: "openai/whisper-large-v3",
        tokenizerRevision: "06f233fe06e710322aca913c1bc4249a0d71fce1",
        tokenizerDigests: [
            "tokenizer.json": "6d8cbd7cd0d8d5815e478dac67b85a26bbe77c1f5e0c6d76d1ce2abc0e5f21ca",
            "tokenizer_config.json": "844b642c73a91359722f47b35705f7174686df33d252695d8572cf9ac03a6389",
        ]
    )

    public static let small = SpeechModel(
        variant: "openai_whisper-small",
        downloadBytes: 486_487_465,
        isMultilingual: true,
        weightsRepository: "argmaxinc/whisperkit-coreml",
        weightsRevision: "0f63a7800b00dd0226abd051b906c246e1907482",
        weightFiles: [
            "AudioEncoder.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "211457b92a0ced67bb8625efe39799a0030c4fc71eb87d7284ea81043caccde7"),
            "AudioEncoder.mlmodelc/coremldata.bin": .init(
                bytes: 347,
                sha256: "d68f152b6573ac55203a3dc8383730e6ecde685c7d2a88815b89820c88e35371"),
            "AudioEncoder.mlmodelc/metadata.json": .init(
                bytes: 1868,
                sha256: "520e147851258b231299c5a13b0b6d7b973572445706af1ca1dfc6276ff42e77"),
            "AudioEncoder.mlmodelc/model.mil": .init(
                bytes: 1_636_668,
                sha256: "760173a125b9fadb2f3fac45e1504781c081d619744bffb476eab06ae20a6972"),
            "AudioEncoder.mlmodelc/model.mlmodel": .init(
                bytes: 155_271,
                sha256: "68ca04660b8b050c68ca54c27d97c47e4133bc591422cb7009de8922d56fb8c9"),
            "AudioEncoder.mlmodelc/weights/weight.bin": .init(
                bytes: 176_323_456,
                sha256: "fe35cef2c9406993a635639b16f373f6debb0215ac115b7bf93fa03c8e10310b"),
            "MelSpectrogram.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07"),
            "MelSpectrogram.mlmodelc/coremldata.bin": .init(
                bytes: 328,
                sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
            "MelSpectrogram.mlmodelc/metadata.json": .init(
                bytes: 1848,
                sha256: "66a60d0babfcae566910a6d699471efde002d92205a7d349e16989ca4d6729d3"),
            "MelSpectrogram.mlmodelc/model.mil": .init(
                bytes: 10_176,
                sha256: "b8063d8e57c113472ac7c2d248e44383568a018978a753c1884ac406b997a374"),
            "MelSpectrogram.mlmodelc/weights/weight.bin": .init(
                bytes: 354_080,
                sha256: "267017e533b5f542d195fd9a775f2ba649075128283ce8e86c63a2ec20de5b07"),
            "TextDecoder.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "39c0d6d55353bc61ef8071081bb958dd1ab7b0b7f2a3338a797f1a64211e084c"),
            "TextDecoder.mlmodelc/coremldata.bin": .init(
                bytes: 633,
                sha256: "b2ccd0b8920701386ab9554f7db47b43e55ee07863280ee5d829d5272839adc2"),
            "TextDecoder.mlmodelc/metadata.json": .init(
                bytes: 4757,
                sha256: "33870a8d1694071f75dfa29314d290e10a2bd693de7268f9419b381056677fc2"),
            "TextDecoder.mlmodelc/model.mil": .init(
                bytes: 392_094,
                sha256: "ebecbd1b3b0350c63541488217811c3f2a75ac72b178b4cfb357f4c300873bd0"),
            "TextDecoder.mlmodelc/model.mlmodel": .init(
                bytes: 313_629,
                sha256: "7ea861c6dfdd866ed0f2e7fe0c3df7459daa44481cb25236e03698dd6d259391"),
            "TextDecoder.mlmodelc/weights/weight.bin": .init(
                bytes: 307_287_346,
                sha256: "bfea8044a8f38e8d33f56585b1e75ce023d3845e2a945e20480bd7e16558016e"),
            "config.json": .init(
                bytes: 1456,
                sha256: "12f8d45c3e5da28148d88d257684e77296e4d922009e1bc5289b05b756859422"),
            "generation_config.json": .init(
                bytes: 2779,
                sha256: "169e76633bb28ac383cdfaad2527e662d0d532a15f8437ce94c02c10bc713b71"),
        ],
        tokenizerRepository: "openai/whisper-small",
        tokenizerRevision: "973afd24965f72e36ca33b3055d56a652f456b4d",
        tokenizerDigests: [
            "tokenizer.json": "27fc476bfe7f17299480be2273fc0608e4d5a99aba2ab5dec5374b4482d1a566",
            "tokenizer_config.json": "2a4c4281cf9f51ac6ccc406fdc711a087afe6530f671fa7b80953edc498275ce",
        ]
    )

    /// Fastest and least accurate, present as a floor for the benchmark rather than a choice.
    public static let base = SpeechModel(
        variant: "openai_whisper-base",
        downloadBytes: 146_719_453,
        isMultilingual: true,
        weightsRepository: "argmaxinc/whisperkit-coreml",
        weightsRevision: "0f63a7800b00dd0226abd051b906c246e1907482",
        weightFiles: [
            "AudioEncoder.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "c4e096b2abd561f00b9b698401df3fbe1a0d0c8d2476ff19cb4e1995680e827e"),
            "AudioEncoder.mlmodelc/coremldata.bin": .init(
                bytes: 347,
                sha256: "e316980638e2099e83cb1a93b903717dc12b3c2168d0ab69113764c3767696ba"),
            "AudioEncoder.mlmodelc/metadata.json": .init(
                bytes: 1863,
                sha256: "d6785fae31c3f86d60058c14c79902f716f106dd9e36af7d3fe78b9c34867fce"),
            "AudioEncoder.mlmodelc/model.mil": .init(
                bytes: 579_125,
                sha256: "dc74813e26fce790fe22a33dcef8be535b9dce566f38a8bdb677f5e07dcf9138"),
            "AudioEncoder.mlmodelc/model.mlmodel": .init(
                bytes: 79_853,
                sha256: "1d42038f84b508da5ce9b953302387ffedc097c346d36a56b765109002b6080e"),
            "AudioEncoder.mlmodelc/weights/weight.bin": .init(
                bytes: 41_189_632,
                sha256: "061ff4d74e5de3937b31288465d6c6f2697f92d121c80b23f51dd26bbdfe642b"),
            "MelSpectrogram.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07"),
            "MelSpectrogram.mlmodelc/coremldata.bin": .init(
                bytes: 328,
                sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
            "MelSpectrogram.mlmodelc/metadata.json": .init(
                bytes: 1848,
                sha256: "f2b08d80d9cdd39fc0ccdbb5fac86a5f8dd9bcaa839706c3568be6fe8abd82d4"),
            "MelSpectrogram.mlmodelc/model.mil": .init(
                bytes: 10_176,
                sha256: "b8063d8e57c113472ac7c2d248e44383568a018978a753c1884ac406b997a374"),
            "MelSpectrogram.mlmodelc/weights/weight.bin": .init(
                bytes: 354_080,
                sha256: "35d74417ef9c765e70f4ef85fe7405015a7086e9af05e3b63a5c2c7c748b2efc"),
            "TextDecoder.mlmodelc/analytics/coremldata.bin": .init(
                bytes: 243,
                sha256: "6ac1227740ecc2fd7a03df50ac6e2a7f7946acfa77069cf2c486ae0255356b95"),
            "TextDecoder.mlmodelc/coremldata.bin": .init(
                bytes: 633,
                sha256: "9f1f6fe409486e2797d3f0c65d9a6d5af596771760548cd86f41939c54cdbe7c"),
            "TextDecoder.mlmodelc/metadata.json": .init(
                bytes: 4753,
                sha256: "0a64b3686b9a4b2eff0792e7df3cfe1b20467ec5d5ac52c0e01c3dbf6697b65d"),
            "TextDecoder.mlmodelc/model.mil": .init(
                bytes: 205_217,
                sha256: "45b9e61a0f286cddcad96e2c890c7a68460adcaa3319c4907ee4f962dfeb2c8b"),
            "TextDecoder.mlmodelc/model.mlmodel": .init(
                bytes: 164_481,
                sha256: "ae260ff7b95d0c957c3c1f4df4dbeaa0ae6c76bacc55eb86caca8f6820d346f0"),
            "TextDecoder.mlmodelc/weights/weight.bin": .init(
                bytes: 104_122_162,
                sha256: "72325d42a4a4ccc8a6fa974ede6cdf2e0770685a5c4f9da94f41495b94d8d174"),
            "config.json": .init(
                bytes: 1464,
                sha256: "67e25477d03bf3a1c34bfd137724beed94b5218d0457e8c1d25f70379a61d9d5"),
            "generation_config.json": .init(
                bytes: 2762,
                sha256: "662a99e3db3067708549d04d5f141910eb455f0935aed0c9b06d707f44bfbcaf"),
        ],
        tokenizerRepository: "openai/whisper-base",
        tokenizerRevision: "e37978b90ca9030d5170a5c07aadb050351a65bb",
        tokenizerDigests: [
            "tokenizer.json": "27fc476bfe7f17299480be2273fc0608e4d5a99aba2ab5dec5374b4482d1a566",
            "tokenizer_config.json": "2a4c4281cf9f51ac6ccc406fdc711a087afe6530f671fa7b80953edc498275ce",
        ]
    )

    /// Every model the app knows how to install, smallest first.
    public static let catalogue: [SpeechModel] = [base, small, largeV3Turbo]

    /// Looks a model up by repository identifier.
    public static func named(_ variant: String) -> SpeechModel? {
        catalogue.first { $0.variant == variant }
    }

    /// Whether this model can be trusted with a given language.
    public func supports(_ language: LanguageCode) -> Bool {
        isMultilingual || language == .english
    }
}
