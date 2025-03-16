# PU Circle - Connecting Students at PU

## Overview
**PU Circle** is a Flutter-based mobile application designed for students at **PU (Presumed University)** to connect, socialize, and build friendships. Inspired by the best aspects of Instagram and Tinder, PU Circle offers a dynamic and engaging platform where students can interact, share their moments, and find new friends with shared interests.

## Features
### **Authentication & User Setup**
- **Login & Signup with Firebase Authentication**
- **Email Verification** during signup
- **Profile Creation**: Users can upload profile pictures, set a bio, and specify their interests
- **Gender Selection**: Male/Female
- **Relationship Status (Single/Not Single)**: Disclaimer - This is private and not shown publicly

### **Instagram-Like Features**
- Users can **create posts** (photos/videos) and interact via **likes**
- **Home Screen** displays posts from users you follow
- **Follow/Unfollow Functionality**
- View **followers and following lists**

### **Tinder-Like Matchmaking Feature**
- **Match Section** helps students find new friends
- **Swiping System**:
    - Swipe **right** to like
    - Swipe **left** to pass
    - If both users swipe right, it's a **match**
- **Heart Animation** appears when a match is found
- Matched users can **start conversations** via an in-app messaging feature
- **Notification System**: Users get notified of matches and interactions
- **Profile Search**: Find and view other profiles easily

### **Messaging System**
- **Chat System** for matched users
- Messages are stored securely in Firebase
- **Predefined Message Option**: "Wanna meet at PU Circle or on a tea post?" - users can tap to send
- Users can directly **visit profiles and start a chat**

### **Admin Panel**
- **Monitor and moderate** user activity
- **Delete posts, users, or messages** if necessary
- **Manually match users** (with a notification saying the algorithm matched them)
- **Prevent Malpractice** and maintain a safe community
- **Admin Login via Passkey**: '79770051419136567648'

### **Additional Features**
- **Photo/Video Uploads** with storage optimization (compressed files to save space)
- **Logout and Report Profile Option**
- **Loading Animations** to ensure smooth user experience while fetching data
- **Attractive UI/UX** with a never-seen-before, smooth, and engaging design


## 📁 Folder Structure

```
lib/
│── firebase/
│   ├── admin_service.dart
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── match_service.dart
│   ├── messaging_service.dart
│   ├── notification_service.dart
│   ├── storage_service.dart
│
│── models/
│   ├── chat_model.dart
│   ├── match_model.dart
│   ├── notification_model.dart
│   ├── post_model.dart
│   ├── user_model.dart
│
│── screens/
│   ├── admin/
│   │   ├── admin_dashboard.dart
│   │   ├── content_moderation.dart
│   │   ├── user_management.dart
│   │
│   ├── auth/
│   │   ├── admin_login_screen.dart
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │
│   ├── home/
│   │   ├── create_post_screen.dart
│   │   ├── home_screen.dart
│   │   ├── post_detail_screen.dart
│   │
│   ├── match/
│   │   ├── match_detail_screen.dart
│   │   ├── match_screen.dart
│   │
│   ├── messaging/
│   │   ├── chat_list_screen.dart
│   │   ├── chat_screen.dart
│   │
│   ├── notifications/
│   │   ├── notification_screen.dart
│   │
│   ├── profile/
│   │   ├── edit_profile_screen.dart
│   │   ├── followers_screen.dart
│   │   ├── profile_screen.dart
│
│── utils/
│   ├── colors.dart
│   ├── constants.dart
│   ├── helpers.dart
│   ├── notification_helper.dart
│   ├── theme.dart
│   ├── retry_helper.dart
│
│── widgets/
│   ├── chat_bubble_widget.dart
│   ├── common_widgets.dart
│   ├── notification_badge_widget.dart
│   ├── notification_item_widget.dart
│   ├── post_widget.dart
│   ├── profile_card_widget.dart
│   ├── match_animation_widget.dart
│
│── main.dart
```

## 🚀 Features

- **Firebase Integration**: Authentication, Firestore database, messaging, and notifications.
- **Match System**: Includes screens for matching and match details.
- **Messaging**: Chat system with a list of conversations and individual chat screens.
- **Notifications**: Users receive and manage notifications for various actions.
- **Profile Management**: Edit profile, follow users, and view profiles.
- **Admin Panel**: Dashboard for content moderation and user management.
- **Theming & Utilities**: Custom colors, themes, and helper functions.

## 🛠️ Setup Instructions

1. Clone the repository:
   ```sh
   git clone <repository_url>
   ```
2. Navigate to the project directory:
   ```sh
   cd <project_folder>
   ```
3. Install dependencies:
   ```sh
   flutter pub get
   ```
4. Set up Firebase:
    - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
    - Enable Firebase Authentication, Firestore, and Cloud Messaging.
5. Run the app:
   ```sh
   flutter run
   ```

## 📌 Contribution Guidelines

- Fork the repository and create a new branch for your changes.
- Follow the coding style and use meaningful commit messages.
- Submit a pull request with a detailed description of changes.

---

Let me know if you need any further modifications! 🚀
