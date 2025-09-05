# CSV Import Format for Taal Trek

## Overview
This document describes the standardized CSV format for importing Dutch vocabulary into Taal Trek.

## File Structure
The CSV file should have the following columns in order:

1. **Word** - The Dutch word (required)
2. **Translation** - The English translation (required)
3. **Deck** - The deck/chapter name (required)
4. **Example** - Example sentence in Dutch (optional)
5. **Article** - Dutch article (de/het) for nouns (optional)
6. **Plural** - Plural form of the word (optional)
7. **Past Tense** - Past tense form (optional)
8. **Future Tense** - Future tense form (optional)
9. **Past Participle** - Past participle form (optional)

## Deck Naming Convention
- Use the format: `Chapter X.Y` where X is the main chapter and Y is the sub-chapter
- Examples: `Chapter 1`, `Chapter 2.1`, `Chapter 3.4`
- The app will automatically create the hierarchy: Chapter 1 → Chapter 1.1, Chapter 1.2, etc.

## CSV Example
```csv
Word,Translation,Deck,Example,Article,Plural,Past Tense,Future Tense,Past Participle
huis,house,Chapter 1,Ik woon in een groot huis.,het,huizen,,,
auto,car,Chapter 1,Ik rijd in een nieuwe auto.,de,auto's,,,
boek,book,Chapter 1,Ik lees een interessant boek.,het,boeken,,,
```

## Import Rules
1. **Special Characters**: All special characters are supported (ä, ö, ü, ß, etc.)
2. **Commas in Content**: If your content contains commas, wrap the field in quotes: `"Hello, world"`
3. **Empty Fields**: Leave fields empty if not applicable (e.g., verbs don't need articles)
4. **Encoding**: Use UTF-8 encoding for proper character support

## Validation
The app will validate:
- Required fields are not empty
- Deck names follow the convention
- No duplicate words within the same deck

## Tips
- Keep translations concise but clear
- Use consistent capitalization
- Include example sentences when possible for better learning
- Group related words in the same deck
- Use the standardized deck naming for consistency across imports

## Troubleshooting
If import fails:
1. Check that all required columns are present
2. Ensure deck names follow the `Chapter X.Y` format
3. Verify UTF-8 encoding
4. Check for extra commas in content (use quotes if needed)
