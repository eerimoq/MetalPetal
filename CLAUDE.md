# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Swift-only fork of [MetalPetal](https://github.com/MetalPetal/MetalPetal), a Metal-based image
processing framework. The upstream Objective-C code has been fully converted to Swift; the fork is
maintained because it is used by the [Moblin](https://github.com/eerimoq/moblin) iOS app. Types keep
their upstream `MTI` prefix and one-type-per-file naming.

`README.md` is the upstream design document and API reference — read it for filter authoring, alpha
types, color spaces and usage examples.

## Commands

Everything goes through the `Makefile`:

```
make build            # swift build (macOS)
make test             # swift test
make build-all        # swift build + xcodebuild for iOS / iOS Simulator / Mac Catalyst / tvOS / examples
make test-all         # swift test + iOS Simulator, Mac Catalyst, tvOS
make style            # swiftformat (maxwidth 110), rewrites files
make style-check      # swiftformat --lint
make lint             # swiftlint --strict
make spell-check      # codespell
make generate         # regenerate generated sources, then `make style`
```

Run a single test (tests use swift-testing, not XCTest):

```
swift test --filter ShaderInterfaceTypeLayoutTests      # a suite, by *type* name
swift test --filter vertexLayout                       # a single @Test function
```

`--filter` matches test IDs (type/function names), not `@Suite` display names — filtering on
`"Shader interface type layout"` silently runs zero tests.

CI (`.github/workflows/swift.yml`) runs style-check, lint, spell-check, `make generate` +
`git diff --exit-code`, and the build/test matrix. `CONTRIBUTING.md` asks for `make build-all`,
`test-all`, `style-check`, `lint` and `spell-check` before a PR.

The `xcodebuild` targets use `-workspace .` — that is the SwiftPM-generated
`.swiftpm/xcode/package.xcworkspace`, not a checked-in workspace file.

## Generated sources — never edit by hand

`make generate` runs the separate SwiftPM package in `Utilities/` and overwrites:

- `Sources/MetalPetal/MTIVector+SIMD.swift`
- `Sources/MetalPetal/MTISIMDArgumentEncoder.swift`
- `Sources/MetalPetal/MTIBlendFormulaSupport.swift`
- `Sources/MetalPetal/Shaders/BlendingShaders.metal`
- `Sources/MetalPetal/Shaders/MultilayerCompositeShaders.metal`

Blend modes are driven by the `blendModes` array in
`Utilities/Sources/BoilerplateGenerator/BoilerplateGenerator.swift`; blend-formula support is parsed
out of `Shaders/MTIShaderLib.h` and `Shaders/MTIShaderFunctionConstants.h`. To change any of the
above, change the generator (or the headers it reads) and re-run `make generate`.

## Architecture

### Render pipeline

`MTIImage` is immutable and holds no bitmap: it wraps an `MTIImagePromise` (the recipe for producing
an `MTLTexture`) plus `cachePolicy`/`samplerDescriptor`. `MTIFilter`s are mutable objects whose
`outputImage` is a *computed* property that asks a static `MTIKernel` to build a new promise — so
reuse an output image rather than reading `outputImage` twice.

Rendering happens in `MTIContext` (`MTIContext.swift`, `MTIContext+Rendering.swift`): it walks the
promise DAG, optionally rewrites it (`MTIRenderGraphOptimization.swift`, concatenating adjacent
render passes), then resolves each promise against an `MTIImageRenderingContext` that owns the
command buffer and texture pool. Context holds all the caches (library, function, render/compute
pipeline, sampler) behind locks; it is thread-safe, `MTIFilter` is not, `MTIImage` is.

Layering, roughly bottom-up:

- `MTIImagePromise.swift` — the extension point for new input sources and fully custom processing
  units; `resolve(with:)` gets direct texture/command-buffer access.
- `Kernels/` — `MTIRenderPipelineKernel`, `MTIComputePipelineKernel`, `MTIMPSKernel`,
  `MTIMultilayerCompositeKernel`, `MTIRenderCommand` (multiple draw calls / MRT in one pass).
  Kernels must be stateless; per-configuration state is cached in the context, keyed by
  `MTIKernelConfiguration.identifier` — that identifier must cover everything `makeKernelState` reads.
- `Filters/` — thin wrappers over kernels. Simple effects subclass `MTIUnaryImageRenderingFilter`
  (override `parameters` and `fragmentFunctionDescriptor()`); `Filter.swift` provides the
  `FilterGraph` / `=>` port-connecting DSL.
- `UI/`, `SceneKit/`, `SpriteKit/`, `MTICoreImage*`, `MTICV*` — I/O and interop edges.

### Shader library loading (important)

`MTIBuiltinLibrary.swift` resolves the builtin library in two ways:

1. `default.metallib` from the resource bundle, when the build system compiled the `.metal` files
   (Xcode builds do this).
2. Otherwise it concatenates `MTIShaderLib.h`, `MTIShaderFunctionConstants.h` and every `.metal`
   file in the bundle into one source string and compiles it at runtime via
   `MTILibrarySourceRegistration` (`MTILibrarySource.swift`, which hands back a `mtilibrary://` URL).
   This is the `swift build` path — `Package.swift` declares `resources: [.process("Shaders")]`, so
   the sources ship in the bundle.

Consequences:

- A new `.metal` file under `Sources/MetalPetal/Shaders/` is picked up automatically, but only if its
  includes are written exactly as `#include "MTIShaderLib.h"` / `#include "MTIShaderFunctionConstants.h"`
  / `#include <TargetConditionals.h>` — the concatenator strips those literal strings.
- Under `swift build`, shader syntax errors surface at first render, not at compile time. `make test`
  is what actually exercises them.
- `MTIFunctionDescriptor(name:)` with no `libraryURL` means the builtin library.

### Swift ↔ Metal struct layout

`MTIShaderInterfaceTypes.swift` re-declares, in Swift, the C structs from `Shaders/MTIShaderLib.h`.
Nothing checks these against each other at build time (the header is only ever compiled by the Metal
compiler), so a mismatch is silent wrong pixels or an out-of-bounds GPU read.
`Tests/MetalPetalTests/ShaderInterfaceTypeLayoutTests.swift` pins size/alignment/offsets — change the
Swift struct and the C header together, and update the test. Encode with
`MemoryLayout<T>.stride`, never `.size` (Swift's `.size` drops trailing padding).

## Testing notes

- Test targets: `MetalPetalTests` (needs a GPU), `MetalPetalPublicApiTests` (API reachability from
  outside the module), plus the `MetalPetalTestHelpers` target for image/video/CLUT generators and a
  pixel enumerator.
- Most suites are gated on `@Suite(.enabled(if: metalDeviceIsAvailable))` — with no Metal device they
  silently skip rather than fail, so a green run on a machine without a GPU proves little.
- MPS-backed filters (`MTIMPS*`, `MTICLAHEFilter`) do not work on the iOS Simulator.
- Render tests compare pixels; `Tests/Fixture/` holds the reference images.
