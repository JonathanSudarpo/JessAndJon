# 🔐 Git Setup & Security Guide

## ⚠️ IMPORTANT: API Keys Security

Your `GoogleService-Info.plist` file contains **real API keys** and must **NOT** be committed to git.

## ✅ What I've Done

1. ✅ Added `GoogleService-Info.plist` to `.gitignore`
2. ✅ Created `GoogleService-Info.plist.example` as a template
3. ✅ Your real keys are now protected

## 🚨 IMPORTANT: Remove API Keys from Git Tracking

**Your `GoogleService-Info.plist` is currently tracked in git!** You need to remove it:

```bash
# 1. Remove from git tracking (but keep the local file)
git rm --cached JessAndJon/GoogleService-Info.plist

# 2. Verify it's now ignored
git status
# GoogleService-Info.plist should show as "deleted" (that's good - it means it's removed from tracking)

# 3. Commit the removal
git commit -m "Remove GoogleService-Info.plist from git (contains API keys)"

# 4. Verify .gitignore is working
git check-ignore -v JessAndJon/GoogleService-Info.plist
# Should output: JessAndJon/GoogleService-Info.plist:42:.gitignore

# 5. Check status again - file should NOT appear
git status
```

**After this, the file will:**
- ✅ Stay on your local machine (not deleted)
- ✅ Be ignored by git (won't be committed)
- ✅ Not be pushed to remote

**⚠️ Note:** If you've already pushed this file to a public repository, you should:
1. **Rotate your API keys** in Firebase Console (they may be exposed)
2. Download a new `GoogleService-Info.plist` from Firebase
3. Follow the steps above to remove it from git

## 📋 Before Pushing to Git

### 1. Check What Will Be Committed

```bash
# See what files will be committed
git status

# Make sure GoogleService-Info.plist is NOT listed
```

### 2. Verify .gitignore is Working

```bash
# Check if GoogleService-Info.plist is ignored
git check-ignore -v JessAndJon/GoogleService-Info.plist

# Should output: JessAndJon/GoogleService-Info.plist:42:.gitignore
```

### 3. Safe Files to Commit

✅ **Safe to commit:**
- All Swift code files
- `GoogleService-Info.plist.example` (template)
- `.gitignore`
- `PRIVACY_POLICY.md`
- `README.md`
- All other documentation files

❌ **Never commit:**
- `GoogleService-Info.plist` (real API keys)
- Any files with passwords or secrets
- `.DS_Store` files (already in .gitignore)

## 🔄 Setting Up on a New Machine

When someone clones your repo:

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd JessAndJon
   ```

2. **Copy the example file:**
   ```bash
   cp JessAndJon/GoogleService-Info.plist.example JessAndJon/GoogleService-Info.plist
   ```

3. **Get your real keys from Firebase:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project: `jessandjon-55f39`
   - Go to Project Settings → General
   - Scroll to "Your apps" → iOS app
   - Click "Download GoogleService-Info.plist"
   - Replace the example file with the real one

4. **Verify it's ignored:**
   ```bash
   git status
   # GoogleService-Info.plist should NOT appear
   ```

## 🔐 Firebase API Key Security

### Are Firebase API Keys Secret?

**Short answer:** Firebase API keys are **public** by design, but you should still protect them.

**Why?**
- Firebase API keys are meant to be embedded in client apps
- They're visible in your app bundle (anyone can extract them)
- Security comes from **Firestore Security Rules**, not hiding the keys

**However:**
- You should still keep them out of git to prevent:
  - Accidental exposure in public repos
  - Easy scraping by bots
  - Unnecessary key rotation if exposed

### Best Practices

1. ✅ **Use Firestore Security Rules** (you already have these)
2. ✅ **Restrict API keys** in Google Cloud Console:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - APIs & Services → Credentials
   - Click on your API key
   - Under "Application restrictions":
     - Select "iOS apps"
     - Add your bundle ID: `com.jessandjon.app`
   - Under "API restrictions":
     - Select "Restrict key"
     - Only enable: Firebase APIs

3. ✅ **Monitor usage** in Firebase Console
4. ✅ **Rotate keys** if exposed

## 📝 Privacy Policy Hosting

### Quick Options

**Option 1: GitHub Pages (Free & Easy)**
1. Create a new GitHub repository (e.g., `lovance-privacy`)
2. Create `index.md` with your privacy policy content
3. Enable GitHub Pages in Settings
4. Your URL: `https://yourusername.github.io/lovance-privacy/`

**Option 2: GitHub Gist (Fastest)**
1. Go to [gist.github.com](https://gist.github.com)
2. Create a new gist: `privacy-policy.md`
3. Make it public
4. Use the "Raw" URL: `https://gist.githubusercontent.com/username/gist-id/raw/privacy-policy.md`

**Option 3: Notion (Easiest)**
1. Create a Notion page with your privacy policy
2. Click "Share" → "Publish to web"
3. Copy the public URL

### Update Privacy Policy

1. Edit `PRIVACY_POLICY.md`
2. Replace placeholders:
   - `[Date]` → Today's date
   - `[your-email@example.com]` → Your support email
   - `[your-website.com]` → Your privacy policy URL (or remove if not applicable)

## ✅ Pre-Push Checklist

Before pushing your branch:

- [ ] **Run `git rm --cached JessAndJon/GoogleService-Info.plist`** ⚠️ REQUIRED
- [ ] `GoogleService-Info.plist` is in `.gitignore` ✅ (Done)
- [ ] `GoogleService-Info.plist` is NOT in `git status` (after removal)
- [ ] Privacy policy placeholders updated
- [ ] Privacy policy hosted online (if ready)
- [ ] No hardcoded secrets in code ✅
- [ ] All sensitive files ignored

## 🚀 Push Your Branch

```bash
# Check status first
git status

# Add all safe files
git add .

# Commit
git commit -m "Add privacy policy and input validation"

# Push to your branch
git push origin your-branch-name
```

---

**Need help?** Check:
- `.gitignore` - See what's ignored
- `PRIVACY_POLICY_GUIDE.md` - Privacy policy hosting guide
- `SECURITY_REVIEW.md` - Security best practices
