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
   - Words should start at Level 1 (🌱) with 0 XP

3. **Verify XP Accumulation**
   - Complete more exercises with the same words
   - Words should gain XP and potentially level up
   - Level 2 (🌿) requires 101 XP
   - Level 3 (🌳) requires 251 XP
   - Level 4 (🏔️) requires 501 XP
   - Level 5 (⭐) requires 751 XP

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

### **Test Scenario 4: Level Up Celebrations**

1. **Trigger a Level Up**
   - Get a word to exactly 100 XP (end of Level 1)
   - Answer one more question correctly
   - The word should level up to Level 2 (🌿)

2. **Check Level Up History**
   - The system should record when the level up occurred
   - You should see the new level immediately

### **Test Scenario 5: Progress Tracking**

1. **Check Progress Bars**
   - Words should show progress within their current level
   - Progress should be 0.0 to 1.0 within each level
   - Colors should change based on progress (red → orange → green)

2. **Check XP Needed**
   - The system should calculate how much XP is needed for the next level
   - Example: At 50 XP, need 51 more for Level 2

### **Test Scenario 6: Data Persistence**

1. **Save and Reload**
   - Complete some exercises and gain XP
   - Close the app completely
   - Reopen the app
   - Verify that word levels and XP are preserved

2. **Check Exercise History**
   - The system should track recent exercise history
   - Should show exercise type, XP gained, and timestamp

### **Expected Results**

✅ **Level Progression:**
- Level 1 (🌱): 0-100 XP - "Beginner"
- Level 2 (🌿): 101-250 XP - "Novice"  
- Level 3 (🌳): 251-500 XP - "Intermediate"
- Level 4 (🏔️): 501-750 XP - "Advanced"
- Level 5 (⭐): 751-1000 XP - "Mastered"
- Level 6 (🌟): 1001-1500 XP - "Expert"
- Level 7 (💫): 1501-2500 XP - "Legendary"
- Level 8 (✨): 2501-5000 XP - "Mythic"
- Level 9 (🔥): 5001-10000 XP - "Divine"
- Level 10 (👑): 10001+ XP - "Transcendent"

✅ **UI Indicators:**
- Level icons should appear next to words
- Progress bars should show level progress
- Colors should change based on progress
- Level-up animations (when implemented)

✅ **Data Integrity:**
- XP should persist between app sessions
- Level calculations should be accurate
- Exercise history should be maintained
- No duplicate exercises should be created

### **Troubleshooting**

If tests fail:

1. **Check Console Logs**
   - Look for XP calculation messages
   - Verify exercise types are being recognized

2. **Verify Data Models**
   - Ensure `LearningMastery` has RPG fields
   - Check that `XPService` is properly integrated

3. **Test Individual Components**
   - Run the automated tests: `flutter test test/rpg_leveling_test.dart`
   - All 21 tests should pass

### **Next Steps for Full Implementation**

Once manual testing confirms the backend works:

1. **UI Integration**
   - Add level icons to word displays
   - Create progress bars for level progress
   - Add level-up celebration animations

2. **End Screen Enhancement**
   - Add swipe-right gesture after study sessions
   - Show word level progress summary
   - Display XP gained during session

3. **User Experience**
   - Add sound effects for level ups
   - Create motivational messages
   - Show streak bonuses in real-time

---

**Note:** This system is designed to make learning more engaging by giving users a sense of progress and achievement for each individual word, similar to character progression in RPG games.
