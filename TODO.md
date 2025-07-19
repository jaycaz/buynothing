# BuyNothing iOS App Development Todo

## Phase 1: Project Setup ✅
- [x] Initialize Git Repository
- [x] Create Xcode project with SwiftUI
- [x] Configure bundle identifier and basic settings
- [x] Set up .gitignore and initial commit

## Phase 2: Core Architecture Setup
- [ ] Create organized folder structure (Models, Views, Services, Utilities)
- [ ] Set up modular architecture for easy feature expansion
- [ ] Create essential data models:
  - [ ] `USBCable` model with port types, speeds, and metadata
  - [ ] `Item` base model for future expansion
  - [ ] `User` model for people-centric features

## Phase 3: USB Cable Proof of Concept
### Camera Integration
- [ ] Implement camera view with AVFoundation
- [ ] Add Core ML model placeholder for cable detection
- [ ] Create image capture and processing pipeline
- [ ] Test camera permissions and functionality

### Hero Visual Interface
- [ ] Design borderless hero image components
- [ ] Implement stunning cable display cards
- [ ] Create smooth animations and transitions
- [ ] Implement responsive layout for different screen sizes

### Voice Integration
- [ ] Add Speech framework for voice commands
- [ ] Implement LLM-powered voice processing (OpenAI API integration)
- [ ] Create voice-to-action mapping for cable selection
- [ ] Test speech recognition permissions and functionality

### Cable Management Features
- [ ] Cable logging and categorization system
- [ ] Intuitive selection interface
- [ ] Search and filter capabilities
- [ ] Cable type detection accuracy improvements

## Phase 4: Foundation for Future Features
### Networking Layer
- [ ] Prepare modular networking architecture
- [ ] API client structure for future backend integration
- [ ] Local data persistence with Core Data
- [ ] Error handling and retry mechanisms

### Testing & Polish
- [ ] Unit tests for core models and services
- [ ] SwiftUI preview implementations for all views
- [ ] Comprehensive error handling and user feedback
- [ ] Performance optimization and memory management

## Next Steps (Future Phases)
- [ ] Expand to other item types beyond USB cables
- [ ] Implement auto-generated collages feature
- [ ] Add social bartering system
- [ ] Develop people-centric connection features
- [ ] Build decentralized or volunteer-funded backend

## Current Focus
**Starting with USB Cable Detection Proof of Concept**
- Priority: Core ML camera recognition
- Goal: Detect USB-A, USB-C, Lightning, Micro-USB automatically
- UI: Beautiful borderless hero images
- UX: Voice commands for hands-free interaction