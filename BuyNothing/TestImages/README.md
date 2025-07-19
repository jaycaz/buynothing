# Test Images for USB Cable Detection

This directory contains test images used for validating the cable detection system during development.

## Directory Structure

- `USB-A/` - USB-A connector test images
- `USB-C/` - USB-C connector test images  
- `Lightning/` - Lightning connector test images
- `Micro-USB/` - Micro-USB connector test images
- `Mini-USB/` - Mini-USB connector test images
- `Test-Cases/` - Special test cases (multiple cables, edge cases, etc.)

## Test Image Categories

### Standard Test Cases
- **Clear shots**: Well-lit, clear images with single cable type
- **Partial visibility**: Cable partially obscured or at angles
- **Multiple cables**: Images with multiple different cable types
- **Poor lighting**: Low light or harsh shadows
- **Blurry images**: Motion blur or out-of-focus images

### File Naming Convention
- `{cable-type}-{scenario}-{number}.jpg`
- Examples:
  - `usb-c-clear-01.jpg`
  - `lightning-partial-02.jpg`
  - `multiple-cables-01.jpg`

## Usage in Tests

These images are referenced in test files using the `TestUtilities` helper:

```swift
let imageHash = TestUtilities.createImageHash(for: .usbC, scenario: "clear")
await mockService.setMockResult(for: imageHash, result: expectedResult)
```

## Adding New Test Images

1. Take high-quality photos of real USB cables
2. Resize to reasonable dimensions (300-800px wide)
3. Use JPEG format with 80% quality
4. Follow naming convention
5. Update test cases to use new images

## Image Requirements

- **Resolution**: 300-800px width recommended
- **Format**: JPEG preferred for file size
- **Background**: Various backgrounds to test robustness
- **Lighting**: Include various lighting conditions
- **Angles**: Multiple viewing angles for each cable type

## Mock Images

During development, we use programmatically generated mock images created by `TestUtilities.generateMockCableImage()`. Real photos should be added as development progresses.