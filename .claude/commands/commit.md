Follow the Git Commit Workflow to prepare and create a commit.

**Step 1: Draft Commit Message**
- Analyze the changes made in this session
- Create a concise, descriptive commit message
- Do NOT include "written by claude code" or "Co-Authored-By: Claude"

**Step 2: Update SettingsView.swift**

Get the data needed:
- Current PT timestamp: Run `TZ="America/Los_Angeles" date "+%b %-d, %Y %-I:%M %p PT"`
- Last 9 commits: Run `git log -9 --pretty=format:"%ad: %s" --date=format:"%b %-d" --no-merges`

Update the file:
- **Line 62**: Update timestamp to current PT time
  - Format: `Text("Oct 5, 2025 3:52 PM PT")`
- **Lines 80-89**: Update Recent Changes section with 10 commits:
  - First item: NEW commit message with today's date (e.g., `RecentCommitRow(message: "Oct 5: Your new commit message")`)
  - Next 9 items: From the git log command above

**Step 3: Show User the Drafted Commit Message**
- Display the commit message clearly
- Ask: "Should I proceed with this commit message, or would you like to adjust it?"
- WAIT for user approval

**Step 4: After User Approves**
- Run: `git add .`
- Run: `git commit -m "$(cat <<'EOF'\n[commit message]\nEOF\n)"`
- Run: `git push`
- Confirm success

**IMPORTANT:** Do NOT commit or push until the user explicitly approves the commit message. If they want to adjust it, update the message and ask again.
