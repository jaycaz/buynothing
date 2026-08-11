## Git Commit Guidelines
- For git commits, create one line that summarizes the purpose of the commit in one sentence, then the next line up to 2 sentences describing how that purpose was achieved, in plain English.

## Build & Runtime Validation
After every major change, before committing, use the xcode-build skill to build the project and validate it runs:

1. Build the project:
   ```bash
   pi --session-dir ./build run -c 'xcode-build build'
   ```

2. Run the project (if applicable):
   ```bash
   pi --session-dir ./build run -c 'xcode-build run'
   ```

3. Review the output for any build errors, warnings, or runtime failures

4. Only commit once the build passes without errors

5. Use git diff to show any unexpected changes
