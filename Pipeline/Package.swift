// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CollagePipeline",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Shared, platform-agnostic image pipeline (segmentation -> alignment -> packing).
        .library(name: "CollagePipeline", targets: ["CollagePipeline"]),
        // Headless CLI that runs the pipeline on Mac and emits screenshots + metrics.
        .executable(name: "pipeline-cli", targets: ["PipelineCLI"]),
        // SwiftUI Mac app for interactively reviewing pipeline stages and tuning
        // algorithm parameters live against a folder of real test photos.
        .executable(name: "PipelineViewer", targets: ["PipelineViewer"])
    ],
    targets: [
        .target(
            name: "CollagePipeline",
            path: "Sources/CollagePipeline"
        ),
        .executableTarget(
            name: "PipelineCLI",
            dependencies: ["CollagePipeline"],
            path: "Sources/PipelineCLI"
        ),
        .executableTarget(
            name: "PipelineViewer",
            dependencies: ["CollagePipeline"],
            path: "Sources/PipelineViewer"
        ),
        .testTarget(
            name: "CollagePipelineTests",
            dependencies: ["CollagePipeline"],
            path: "Tests/CollagePipelineTests",
            resources: [.process("TestImages")]
        )
    ]
)
