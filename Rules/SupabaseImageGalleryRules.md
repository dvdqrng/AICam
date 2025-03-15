# Supabase Image Gallery Implementation Plan & Rules

## App Overview
Create an iOS app that displays images stored in Supabase with the following features:
- Display images at the top of the screen
- Include a slider at the bottom to scroll through images
- Show the date the image was taken as the title

## Implementation Plan

### 1. Project Setup (Day 1)
- [ ] Install necessary dependencies
  - [ ] Add Supabase Swift SDK via Swift Package Manager
  - [ ] Set up environment for API keys and configuration
- [ ] Create basic project structure
  - [ ] Models folder for data models
  - [ ] Views folder for UI components
  - [ ] Services folder for API and business logic

### 2. Supabase Integration (Day 2)
- [ ] Configure Supabase client
  - [ ] Create a SupabaseService class to handle all Supabase interactions
  - [ ] Implement authentication if needed
- [ ] Create data models
  - [ ] Design Image model with appropriate fields (url, date, id, etc.)
- [ ] Implement image fetching functionality
  - [ ] Create methods to fetch images from Supabase
  - [ ] Add pagination support for efficient loading

### 3. UI Implementation (Day 3-4)
- [ ] Design main image viewer screen
  - [ ] Implement image view component at the top
  - [ ] Add title showing the date image was taken
  - [ ] Create slider component at the bottom
- [ ] Implement image caching for performance
  - [ ] Use URLCache or a third-party library for image caching
- [ ] Add loading states and error handling

### 4. Testing & Refinement (Day 5)
- [ ] Test the app with actual Supabase data
- [ ] Optimize image loading and caching
- [ ] Add animations and transitions between images
- [ ] Implement error handling and recovery strategies

### 5. Finalization (Day 6)
- [ ] Polish UI
- [ ] Perform final testing
- [ ] Document code and features
- [ ] Prepare for deployment

## Architecture Rules

### Supabase Configuration
1. Store Supabase API keys securely using environment variables or Xcode configuration
2. All Supabase interactions must go through the SupabaseService class
3. Implement proper error handling for all API requests

### Image Handling
1. Use efficient loading techniques to minimize data usage
2. Implement caching to improve performance
3. Support multiple image formats (JPEG, PNG, etc.)
4. Ensure images are displayed at appropriate resolutions

### UI Guidelines
1. Follow iOS Human Interface Guidelines
2. Support dark mode and light mode
3. Ensure accessibility compliance
4. Implement smooth transitions between images
5. Display clear loading indicators during image fetching

### Code Structure
1. Follow MVVM architecture pattern
2. Create reusable components for common UI elements
3. Separate business logic from UI code
4. Use Swift's async/await for asynchronous operations
5. Write meaningful comments and documentation

### Testing
1. Write unit tests for core functionality
2. Test on multiple device sizes
3. Include error handling tests
4. Verify performance with large datasets

## Supabase Table Structure

The Supabase table should include the following fields:
- `id`: Unique identifier for each image (UUID)
- `url`: The URL or path to the image
- `created_at`: Timestamp when the image was added to the database
- `photo_date`: Date when the photo was taken
- `metadata`: JSON field for additional information (optional)

## Implementation Guidelines

1. Use SwiftUI for building the UI
2. Implement proper error handling and recovery
3. Optimize for performance with lazy loading and caching
4. Follow Swift best practices and coding standards
5. Ensure responsive design for different device sizes 