# App Store Update Guide - SteveFlashCard Flutter Migration

## Overview
This guide explains how to update your existing SteveFlashCard app on the App Store with the new Flutter build, avoiding the duplicate app rejection.

## Changes Made

### 1. Bundle Identifier Updated
- **iOS**: Changed from `com.skmonio.taaltrek2` to `Dutch.FlashCard`
- **Android**: Changed from `com.skmonio.taaltrek` to `dutch.flashcard`

### 2. App Display Name
- Updated to "SteveFlashCard" to match your existing Swift app

### 3. Version Number
- Updated to `3.2.0+32` (higher than your existing Swift app at version 3.1)

### 4. Files Modified
- `ios/Runner.xcodeproj/project.pbxproj` - Bundle identifier and display name
- `ios/Runner/Info.plist` - Display name
- `android/app/build.gradle.kts` - Package name and application ID
- `android/app/src/main/AndroidManifest.xml` - Package name and app label
- `android/app/src/main/kotlin/dutch/flashcard/MainActivity.kt` - New package structure
- `pubspec.yaml` - Version number

## Next Steps

### 1. Upload to App Store Connect
1. Open **Transporter** app on your Mac
2. Drag and drop the IPA file from: `build/ios/ipa/Runner.ipa`
3. Upload to App Store Connect

### 2. Update Existing App Listing
1. Go to **App Store Connect** → **My Apps**
2. Select your existing **SteveFlashCard** app
3. Click **+ Version** to create a new version
4. Set version number to **3.2.0**
5. Upload the new build
6. Update "What's New" section with improvements

### 3. What's New Text Suggestion
```
Version 3.2.0 - Flutter Migration

Major Update:
• Complete app rewrite using Flutter for better performance and stability
• Enhanced UI/UX with modern design patterns
• Improved study modes and learning algorithms
• Better offline functionality
• Optimized memory usage and battery life
• Enhanced accessibility features
• Bug fixes and performance improvements

This update maintains all your existing data while providing a significantly improved learning experience.
```

### 4. Remove Duplicate Listing
If you created a separate listing for the Flutter app, you should:
1. Go to App Store Connect
2. Find the duplicate "Taal Trek" listing
3. Remove it or mark it as "Developer Removed from Sale"

## Important Notes

### Bundle ID Matching
- The bundle identifier `Dutch.FlashCard` must match your existing Swift app
- This allows you to update the existing app instead of creating a duplicate

### Version Number
- Version 3.2.0 is higher than your existing 3.1, ensuring it's recognized as an update
- Build number 32 provides room for future updates

### Signing
- The app is signed with your existing development team (33JRS76UKD)
- This ensures compatibility with your existing App Store listing

## Verification

Before uploading, verify:
- [ ] Bundle identifier matches existing app
- [ ] Version number is higher than current version
- [ ] App name matches existing app
- [ ] IPA builds successfully
- [ ] All features work correctly

## Support

If you encounter any issues:
1. Check that the bundle identifier `Dutch.FlashCard` exactly matches your existing Swift app
2. Ensure you're updating the correct app listing in App Store Connect
3. Verify the version number is higher than the current live version
4. Make sure you're signed with the same Apple Developer account

## Files Generated
- **IPA File**: `build/ios/ipa/Runner.ipa` (ready for upload)
- **Archive**: `build/ios/archive/Runner.xcarchive` (for Xcode distribution)
