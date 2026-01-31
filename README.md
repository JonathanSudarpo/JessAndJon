# 💕 Jess & Jon - Couples Widget App

A beautiful iOS app for couples to stay connected through photos, notes, drawings, and status updates that appear on each other's home screen widgets!

![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue)
![iOS](https://img.shields.io/badge/iOS-17.0+-green)
![WidgetKit](https://img.shields.io/badge/WidgetKit-Enabled-purple)

## ✨ Features

### 📸 Photo Sharing
- Take photos or choose from your library
- Add sweet captions
- Photos appear on your partner's widget instantly

### 📝 Notes & Drawings
- Write love notes with beautiful typography
- Draw cute doodles with a full-featured canvas
- Quick notes for common messages ("Missing you", "Thinking of you", etc.)

### 💭 Status Updates
- Set your current status with fun emojis
- Pre-made statuses for common feelings
- Custom status messages

### 🖼️ Home Screen Widget
- Beautiful widget in 3 sizes (small, medium, large)
- Shows latest content from your partner
- Soft pink/purple gradient design

### 📅 Monthly Memories
- Automatic collage generation
- Slideshow of your month's moments
- Anniversary tracking & countdown

## 🚀 Getting Started

### Requirements

- **macOS** with Xcode 15.0+ (iOS development requires a Mac)
- **Apple Developer Account** ($99/year) for testing on real devices
- **Two iPhones** (for you and your partner)
- **Firebase Account** (free) for syncing data

### Running on Windows (Your Situation)

Unfortunately, **iOS apps can only be built on macOS** - this is an Apple limitation. Here are your options:

#### Option 1: Use a Mac (Recommended)
- Borrow a friend's Mac
- Use a Mac at a library or school
- Rent a Mac in the cloud (MacStadium, MacinCloud)

#### Option 2: Virtual Machine
- Run macOS in a VM (VMware/VirtualBox) - Note: This violates Apple's EULA

#### Option 3: CI/CD Service
- Use a service like GitHub Actions with macOS runners
- Or services like Codemagic, Bitrise for iOS builds

### Step-by-Step Setup (on Mac)

#### 1. Open Project in Xcode
```bash
cd JessAndJon
open JessAndJon.xcodeproj
```

#### 2. Set Up Firebase
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project called "JessAndJon"
3. Add an iOS app with bundle ID: `com.jessandjon.app`
4. Download `GoogleService-Info.plist`
5. Replace the placeholder file in `JessAndJon/JessAndJon/GoogleService-Info.plist`

#### 3. Add Firebase SDK
In Xcode:
1. File → Add Package Dependencies
2. Add: `https://github.com/firebase/firebase-ios-sdk`
3. Select these packages:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage

#### 4. Configure App Group
1. Select the project in Xcode
2. Select "JessAndJon" target → Signing & Capabilities
3. Click "+ Capability" → Add "App Groups"
4. Add group: `group.com.jessandjon.app`
5. Repeat for "LoveWidgetExtension" target

#### 5. Set Your Team
1. Select project → Signing & Capabilities
2. Set your Team for both targets
3. If needed, change bundle ID to something unique

#### 6. Run on Simulator
1. Select an iPhone simulator (iPhone 15 Pro recommended)
2. Press ⌘+R or click the Play button
3. The app will build and launch in the simulator

#### 7. Run on Real Device
1. Connect your iPhone via USB
2. Select your device in Xcode
3. First time: Trust the developer certificate on your iPhone
4. Press ⌘+R to build and run

### Testing the Widget

1. Build and run the app on your device/simulator
2. Go to Home Screen
3. Long press → Edit Home Screen
4. Tap + in top left
5. Search for "Jess & Jon" or "Love Widget"
6. Add widget to home screen

## 📱 App Architecture

```
JessAndJon/
├── JessAndJon.xcodeproj      # Xcode project file
├── JessAndJon/               # Main app
│   ├── JessAndJonApp.swift   # App entry point
│   ├── ContentView.swift     # Main tab view
│   ├── Views/                # All screens
│   │   ├── OnboardingView.swift
│   │   ├── PhotoView.swift
│   │   ├── NotesView.swift
│   │   ├── StatusView.swift
│   │   ├── MemoriesView.swift
│   │   └── PartnerWidgetView.swift
│   ├── Models/               # Data models
│   │   ├── Models.swift
│   │   └── Theme.swift
│   ├── Services/             # Backend services
│   │   └── FirebaseService.swift
│   └── Components/           # Reusable UI components
│       ├── DrawingCanvas.swift
│       ├── ImagePicker.swift
│       └── Components.swift
└── LoveWidgetExtension/      # Widget
    ├── LoveWidgetBundle.swift
    └── LoveWidget.swift
```

## 🔥 Setting Up Firebase (Full Backend)

To enable real syncing between devices:

### Firestore Database Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /content/{contentId} {
      allow read, write: if request.auth != null;
    }
    match /couples/{coupleId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /images/{imageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Enable Authentication
1. Firebase Console → Authentication
2. Enable "Anonymous" sign-in method

## 🎨 Customization

### Changing App Name
1. Edit `Info.plist` → `CFBundleDisplayName`
2. Update strings in code as needed

### Changing Colors
Edit `Theme.swift`:
```swift
static let gradientStart = Color(hex: "YOUR_COLOR")
static let gradientEnd = Color(hex: "YOUR_COLOR")
```

### Adding More Statuses
Edit `Models.swift` → `StatusOption.options` array

## 💡 Tips

1. **Widget Updates**: iOS widgets refresh periodically (every 15-60 min). For faster updates, the app uses App Groups to share data.

2. **Push Notifications**: For instant updates, you'll need to set up Firebase Cloud Messaging (FCM) - this requires additional backend setup.

3. **Testing**: Use two simulators or two devices signed into different accounts to test the partner connection.

## 🐛 Troubleshooting

### "Widget not showing"
- Make sure both targets have the same App Group
- Rebuild the app and widget
- Restart your device

### "Can't connect to partner"
- Check internet connection
- Verify Firebase is configured correctly
- Make sure both users created accounts

### "Photos not syncing"
- Firebase Storage must be enabled
- Check storage rules allow uploads

## 📄 License

This project is for personal use between Jess & Jon. 💕

---

Made with ❤️ for couples who want to stay connected!
