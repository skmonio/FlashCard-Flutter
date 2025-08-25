# Dutch Grammar Exercise Generation

## Overview

The app now automatically generates Dutch grammar exercises when users add cards with additional grammar data (articles and plural forms). This feature helps users practice Dutch grammar rules alongside vocabulary learning.

## How It Works

### Automatic Exercise Generation

When a user creates or updates a flashcard with grammar data, the system automatically generates relevant exercises:

1. **Article Exercise**: If an article (De/Het) is provided
   - Question: "Is it De or Het [word]?"
   - Options: De, Het
   - Correct answer: The provided article

2. **Plural Exercise**: If a plural form is provided
   - Question: "What is the plural form of [word]?"
   - Options: Correct plural + 3 plausible wrong options
   - Correct answer: The provided plural form

### Wrong Option Generation

For plural exercises, the system generates plausible wrong options based on Dutch grammar rules:

- **-en ending**: Most common plural ending
- **-s ending**: For words ending in -el, -er, -en, -em, -ie, -je, -ke, -le, -me, -ne, -re, -se, -te, -ue, -ze
- **-eren ending**: For some neuter nouns (like kind -> kinderen)
- **-den ending**: For words ending in -d
- **-ten ending**: For words ending in -t
- **-s ending**: For words ending in -a, -o, -u, -y
- **-en ending**: For words ending in -ing
- **-s ending**: For words ending in -heid
- **-en ending**: For words ending in -nis
- **-en ending**: For words ending in -schap
- **-s ending**: For words ending in -isme
- **-en ending**: For words ending in -teit
- **-s ending**: For words ending in -ment
- **-en ending**: For words ending in -sel
- **-s ending**: For words ending in -aar

### Integration with Existing System

- Exercises are automatically added to the Dutch Word Exercise system
- If a word already has exercises, new grammar exercises are added to the existing set
- If no exercises exist for the word, a new Dutch Word Exercise is created
- Exercises are linked to the same deck as the flashcard

## Usage

### For Users

1. **Add a card with grammar data**:
   - Fill in the word and definition
   - Optionally add the article (De/Het)
   - Optionally add the plural form
   - Save the card

2. **Grammar exercises are automatically created** and available in:
   - Dutch Words practice mode
   - Individual word exercise views
   - Shuffle mode (if enabled)

### For Developers

The feature is implemented through:

- `DutchGrammarExerciseGenerator`: Service that creates exercises
- `FlashcardProvider`: Modified to auto-generate exercises on card creation/update
- Integration with existing `DutchWordExerciseProvider`

## Example

**Input Card:**
- Word: "hond"
- Definition: "dog"
- Article: "de"
- Plural: "honden"

**Generated Exercises:**

1. **Article Exercise:**
   - Question: "Is it De or Het 'hond'?"
   - Options: ["de", "het"]
   - Correct: "de"

2. **Plural Exercise:**
   - Question: "What is the plural form of 'hond'?"
   - Options: ["honden", "honds", "honden", "honden"]
   - Correct: "honden"

## Benefits

- **Automatic**: No manual exercise creation required
- **Grammar-focused**: Helps users learn Dutch grammar rules
- **Integrated**: Works seamlessly with existing vocabulary learning
- **Scalable**: Generates exercises for any word with grammar data
- **Educational**: Uses realistic wrong options based on Dutch grammar patterns
