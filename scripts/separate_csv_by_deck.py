#!/usr/bin/env python3
"""
Script to separate Steve Cards.csv into individual CSV files by deck
"""

import csv
import os
from collections import defaultdict

def separate_csv_by_deck(input_file, output_dir):
    """Separate CSV file into individual files by deck"""
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Dictionary to store cards by deck
    deck_cards = defaultdict(list)
    
    # Read the input CSV file
    with open(input_file, 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            deck_name = row['Decks'].strip()
            if deck_name:  # Skip empty deck names
                deck_cards[deck_name].append(row)
    
    # Write individual CSV files for each deck
    for deck_name, cards in deck_cards.items():
        # Create a safe filename
        safe_filename = deck_name.replace('>', '-').replace(' ', '_').replace('/', '_')
        output_file = os.path.join(output_dir, f"{safe_filename}.csv")
        
        with open(output_file, 'w', encoding='utf-8', newline='') as file:
            if cards:
                # Get fieldnames from the first card
                fieldnames = cards[0].keys()
                writer = csv.DictWriter(file, fieldnames=fieldnames)
                
                # Write header
                writer.writeheader()
                
                # Write cards
                for card in cards:
                    writer.writerow(card)
        
        print(f"Created {output_file} with {len(cards)} cards")

def create_store_metadata(output_dir):
    """Create metadata for the store"""
    
    metadata = {
        "store_packs": []
    }
    
    # Scan for CSV files and create metadata
    for filename in os.listdir(output_dir):
        if filename.endswith('.csv'):
            deck_name = filename.replace('.csv', '').replace('_', ' ').replace('-', ' > ')
            
            # Count cards in the file
            card_count = 0
            csv_path = os.path.join(output_dir, filename)
            with open(csv_path, 'r', encoding='utf-8') as file:
                reader = csv.DictReader(file)
                card_count = sum(1 for row in reader)
            
            pack_info = {
                "id": deck_name.lower().replace(' ', '_').replace('>', '').replace(' ', ''),
                "name": deck_name,
                "description": f"Vocabulary pack with {card_count} Dutch words and phrases",
                "card_count": card_count,
                "filename": filename,
                "unlocked": False,
                "category": "vocabulary",
                "difficulty": "beginner" if "basics" in deck_name.lower() else "intermediate"
            }
            
            metadata["store_packs"].append(pack_info)
    
    # Write metadata to JSON file
    import json
    metadata_file = os.path.join(output_dir, "store_metadata.json")
    with open(metadata_file, 'w', encoding='utf-8') as file:
        json.dump(metadata, file, indent=2, ensure_ascii=False)
    
    print(f"Created store metadata: {metadata_file}")

if __name__ == "__main__":
    input_file = "assets/data/Steve Cards.csv"
    output_dir = "assets/data/store_packs"
    
    print("Separating CSV by deck...")
    separate_csv_by_deck(input_file, output_dir)
    
    print("Creating store metadata...")
    create_store_metadata(output_dir)
    
    print("Done!")
