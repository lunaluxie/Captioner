// swift-tools-version: 6.2
import PackageDescription

// A thin wrapper around FluidAudio's offline speaker diarization, so the apps depend on one
// small API and FluidAudio's optional text-normalization binary (NemoTextProcessing, tens of
// megabytes) stays out of the build.
let package = Package(
    name: "SpeakerDiarization",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SpeakerDiarization", targets: ["SpeakerDiarization"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7", traits: []),
    ],
    targets: [
        .target(name: "SpeakerDiarization", dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]),
    ]
)
