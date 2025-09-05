#!/usr/bin/env python3
"""
Convert existing CSV format to standardized format for Taal Trek
"""

import csv
import os

def convert_deck_name(deck_name):
    """Convert deck names to standardized format"""
    if not deck_name:
        return "Chapter 1"
    
    # Handle existing "Chapter X" format
    if deck_name.startswith("Chapter"):
        return deck_name
    
    # Handle numeric format like "2.4" -> "Chapter 2.4"
    if deck_name.replace('.', '').isdigit():
        return f"Chapter {deck_name}"
    
    # Handle other formats
    return f"Chapter {deck_name}"

def clean_translation(translation):
    """Clean up translations by removing extra spaces and fixing formatting"""
    if not translation:
        return ""
    
    # Remove extra spaces
    cleaned = " ".join(translation.split())
    
    # Fix common formatting issues
    cleaned = cleaned.replace("The approach The method", "The approach")
    cleaned = cleaned.replace("Varied Diverse", "Varied diverse")
    cleaned = cleaned.replace("Labour job market", "Labour job market")
    cleaned = cleaned.replace("to treat/to handle", "To treat/to handle")
    cleaned = cleaned.replace("afterwards later in hindsight", "Afterwards later in hindsight")
    cleaned = cleaned.replace("stuffy/breathless", "Stuffy/breathless")
    cleaned = cleaned.replace("Limitation Restriction Disability", "Limitation restriction disability")
    cleaned = cleaned.replace("to discuss to talk about to review", "To discuss to talk about to review")
    cleaned = cleaned.replace("package insert", "Package insert")
    cleaned = cleaned.replace("side effect", "Side effect")
    cleaned = cleaned.replace("As a result because of", "As a result because of")
    cleaned = cleaned.replace("On the other hand", "On the other hand")
    cleaned = cleaned.replace("Heal Cure Recover", "Heal cure recover")
    cleaned = cleaned.replace("To function To operate To perform", "To function to operate to perform")
    cleaned = cleaned.replace("Spiritual Mentally", "Spiritual mentally")
    cleaned = cleaned.replace("hearing protection", "Hearing protection")
    cleaned = cleaned.replace("Consequence Result Effect", "Consequence result effect")
    cleaned = cleaned.replace("borders/limits", "Borders/limits")
    cleaned = cleaned.replace("Trade business", "Trade business")
    cleaned = cleaned.replace("Its not so bad", "It's not so bad")
    cleaned = cleaned.replace("cough syrup", "Cough syrup")
    cleaned = cleaned.replace("expiration date", "Expiration date")
    cleaned = cleaned.replace("posture/attitude", "Posture/attitude")
    cleaned = cleaned.replace("Commit burglary", "Commit burglary")
    cleaned = cleaned.replace("Ready Made", "Ready made")
    cleaned = cleaned.replace("Cart/Trolley", "Cart/trolley")
    cleaned = cleaned.replace("Stay Sleepover (temp)", "Stay sleepover (temp)")
    cleaned = cleaned.replace("measure/action", "Measure/action")
    cleaned = cleaned.replace("Label Sticker", "Label sticker")
    
    return cleaned

def convert_csv(input_file, output_file):
    """Convert CSV from old format to standardized format"""
    
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        reader = csv.reader(infile)
        writer = csv.writer(outfile)
        
        # Read header
        header = next(reader)
        writer.writerow(header)
        
        # Process each row
        for row in reader:
            if len(row) >= 3:
                # Clean up the data
                word = row[0].strip()
                translation = clean_translation(row[1])
                deck = convert_deck_name(row[2])
                
                # Create new row with cleaned data
                new_row = [word, translation, deck]
                
                # Add remaining columns if they exist
                for i in range(3, len(row)):
                    new_row.append(row[i].strip())
                
                # Ensure we have all 9 columns
                while len(new_row) < 9:
                    new_row.append("")
                
                writer.writerow(new_row)
            else:
                # Skip malformed rows
                continue

def main():
    input_file = "../assets/data/dutch_words_import.csv"
    output_file = "../assets/data/dutch_words_import_standardized.csv"
    
    if not os.path.exists(input_file):
        print(f"Input file not found: {input_file}")
        return
    
    try:
        convert_csv(input_file, output_file)
        print(f"Successfully converted {input_file} to {output_file}")
        print("The standardized format uses 'Chapter X.Y' naming convention")
        print("and cleans up translation formatting.")
    except Exception as e:
        print(f"Error converting file: {e}")

if __name__ == "__main__":
    main()
