# Example Translation Feature

## Overview

The app now supports adding translations for example sentences when creating or editing flashcards. This feature helps users better understand the context and meaning of Dutch example sentences.

## How It Works

### Adding Example Translations

When adding or editing a card, users can now:

1. **Enter the Dutch example sentence** in the "Example Sentence" field
2. **Add an English translation** in the new "Example Translation (optional)" field underneath
3. **Both fields are optional** - users can add either, both, or neither

### UI Changes

**New Field Added:**
- **Label**: "Example Translation (optional)"
- **Hint**: "e.g., I live in a big house."
- **Icon**: Translate icon
- **Position**: Directly below the Example Sentence field
- **Max Length**: 300 characters

### Display in App

The example translation is now displayed in several places throughout the app:

1. **Card Lists**: Shows both Dutch example and English translation (if provided)
2. **Card Details**: Displays example translation in card detail dialogs
3. **Store View**: Shows example translations in store pack previews
4. **Study Views**: Example translations are preserved and displayed during study sessions

### Visual Design

- **Dutch Example**: Displayed in normal text
- **English Translation**: Displayed in slightly smaller, italicized text with reduced opacity
- **Hierarchy**: Translation appears below the Dutch example for clear visual separation

## Technical Implementation

### Data Model Changes

**FlashCard Model Updates:**
- Added `exampleTranslation` field to store the English translation
- Updated constructor, copyWith, toJson, and fromJson methods
- Maintains backward compatibility with existing cards

### Service Layer Updates

**FlashcardService:**
- Updated `createCard` method to accept `exampleTranslation` parameter
- Handles empty translations gracefully

**FlashcardProvider:**
- Updated provider methods to pass through example translation data
- Maintains existing functionality for cards without translations

### Import/Export Support

**Unified Import Service:**
- Supports importing cards with example translations from CSV
- Handles missing translation fields gracefully

## Benefits

1. **Better Context**: Users can understand Dutch examples more easily
2. **Learning Aid**: Translations help reinforce vocabulary and grammar
3. **Flexible**: Optional field doesn't require users to provide translations
4. **Consistent**: Translations are displayed consistently across the app
5. **Backward Compatible**: Existing cards continue to work without changes

## Usage Examples

### Adding a Card with Example Translation

```
Dutch Word: huis
Definition: house
Example Sentence: Ik woon in een groot huis.
Example Translation: I live in a big house.
```

### Display in App

The card will show:
- **Dutch**: "Ik woon in een groot huis."
- **English**: "I live in a big house." (in smaller, italic text)

## Future Enhancements

Potential improvements could include:
- Auto-translation of example sentences using Google Translate API
- Support for multiple translations per example
- Translation validation and suggestions
- Export/import of translation data separately
