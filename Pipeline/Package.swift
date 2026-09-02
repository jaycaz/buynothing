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
        .executable(name: "pipeline-cli", targets: ["PipelineCLI"])
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
        .testTarget(
            name: "CollagePipelineTests",
            dependencies: ["CollagePipeline"],
            path: "Tests/CollagePipelineTests",
            resources: [.process("TestImages")]
        )
    ]
)
