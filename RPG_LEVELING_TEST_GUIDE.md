# RPG Leveling System - Manual Test Guide

## 🎮 How to Test the RPG Leveling System

### **Prerequisites**
- The app should be running with the latest code
- You should have some flashcards in your deck

### **Test Scenario 1: Basic XP and Leveling**

1. **Start a Study Session**
   - Go to "Study Your Cards" or any exercise mode
   - Complete a few questions correctly
   - Note: Each correct answer should award XP to individual words

2. **Check Word Levels**
   - After completing a session, go to your word list
   - Look for level indicators (🌱, 🌿, 🌳, etc.) next to words
   - Words should start at Level 0 (🌱) with 0 XP

3. **Verify XP Accumulation**
   - Complete more exercises with the same words
   - Words should gain XP and potentially level up
   - Level 0 (🌱) = 0 XP (starting level)
   - Level 1 (🌿) requires 1-25 XP
   - Level 2 (🌳) requires 26-75 XP
   - Level 3 (🏔️) requires 76-150 XP
   - Level 4 (⭐) requires 151-250 XP
   - Level 5 (🌟) requires 251-400 XP

### **Test Scenario 2: Different Exercise Types**

Test that different exercise types award different XP:

- **Multiple Choice**: 10 XP
- **True/False**: 15 XP  
- **Word Scramble**: 20 XP
- **Writing**: 25 XP
- **Sentence Building**: 30 XP
- **De/Het**: 15 XP
- **Plural**: 20 XP
- **Fill-in-Blank**: 15 XP

### **Test Scenario 3: Streak Bonuses**

1. **Get a Streak Going**
   - Answer 3 questions correctly in a row: +5 XP bonus
   - Answer 5 questions correctly in a row: +10 XP bonus
   - Answer 10 questions correctly in a row: +25 XP bonus
   - Answer 20 questions correctly in a row: +50 XP bonus

2. **Verify Bonus XP**
   - Check that words gain extra XP during streaks
   - Example: Multiple choice with 3-streak = 15 XP (10 + 5)

### **Test Scenario 4: Daily Diminishing Returns**

1. **Test Daily XP Limits**
   - Study the same word multiple times in one day
   - First attempt: Full XP (e.g., 10 XP for multiple choice)
   - Second attempt: Reduced XP (e.g., 9 XP)
   - Third attempt: Further reduced (e.g., 8 XP)
   - Continue until XP reaches 0

2. **Verify Daily Reset**
   - Wait until the next day or manually reset daily attempts
   - XP should return to full amount for the first attempt

### **Test Scenario 5: Memory Game Partial XP (NEW)**

1. **Test Incorrect Match Tracking**
   - Start a "Remember Your Cards" game
   - Intentionally make an incorrect match (select two cards that don't match)
   - Check the console logs for: "Tracked incorrect match for cards: [word1] and [word2]"
   - The cards should be tracked internally for partial XP

2. **Test Partial XP Award**
   - After making an incorrect match, continue playing
   - When you eventually match one of those cards correctly
   - Check the console logs for: "Awarded [X] XP to word [word] (Correct: true, was previously incorrect)"
   - The XP should be half of the normal amount (e.g., 2-3 XP instead of 5 XP)

3. **Verify Partial XP Logic**
   - Normal correct match: Full XP (e.g., 5 XP)
   - Previously incorrect card now correctly matched: Half XP (e.g., 2-3 XP)
   - This encourages learning from mistakes while still rewarding correct matches

4. **Test Multiple Incorrect Attempts**
   - Make the same card incorrect multiple times
   - When finally matched correctly, it should still get partial XP
   - The partial XP is based on the current daily diminishing returns

5. **Test Game Reset**
   - Complete a memory game with some incorrect matches
   - Start a new game with the same cards
   - Previously incorrect cards should start fresh (no partial XP tracking)

### **Test Scenario 6: Word Progress Display**

1. **Check Word Progress Screen**
   - After completing any exercise, swipe right on the results screen
   - You should see a detailed breakdown of XP gained per word
   - Words should show their current level and XP progress

2. **Test Study Again Feature**
   - From the word progress screen, tap "Study Again"
   - The game should reset and start fresh
   - All tracking should be cleared for the new session

### **Test Scenario 7: Level Up Notifications**

1. **Trigger Level Ups**
   - Study words until they level up
   - You should see level up notifications
   - Check that the word's level indicator changes in the word list

2. **Verify Level Progression**
   - Words should progress through levels: 🌱 → 🌿 → 🌳 → 🏔️ → ⭐ → 🌟
   - Each level requires more XP than the previous

### **Debugging Tips**

- Check console logs for XP-related messages starting with "🔍"
- Look for messages about XP being awarded, daily attempts, and level ups
- If XP isn't working, check that the UserProfileProvider is properly initialized
- Verify that cards have proper LearningMastery objects attached

### **Expected Behavior Summary**

- **Correct answers**: Full XP based on exercise type
- **Incorrect answers**: 0 XP
- **Memory game incorrect matches**: Tracked for partial XP when eventually matched correctly
- **Streaks**: Bonus XP for consecutive correct answers
- **Daily limits**: Diminishing returns for repeated attempts
- **Level ups**: Automatic progression through word levels
- **Persistence**: XP and levels saved between sessions
