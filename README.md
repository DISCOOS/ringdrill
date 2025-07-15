# ringdrill

Plan, synchronize and execute station-based drills with teams and supervisors.

## Getting Started
To get started with developing for RingDrill using Flutter, follow these steps:

1. **Clone the Repository**:  
   Clone the RingDrill repository to your local machine:
   ```bash
   git clone https://github.com/DISCOOS/ringdrill.git
   ```

2. **Set Up Development Environment**:  
   Ensure you have the following prerequisites installed:
    - [Flutter SDK](https://flutter.dev/docs/get-started/install)
    - Appropriate code editor (e.g., [Android Studio](https://developer.android.com/studio) with the Flutter and Dart plugins or [Visual Studio Code](https://code.visualstudio.com/) with Flutter extension)
    - JDK 17 or higher if you're targeting Android
    - Xcode installed if you're targeting iOS

3. **Configure the Project**:
    - Run the following commands in the project’s root directory to ensure all dependencies are installed:
      ```bash
      flutter pub get
      ```
    - If you're targeting Android, verify and set the `compileSdkVersion` in the `android/app/build.gradle` file to match the target SDK version (34 in this case).
    - If you're targeting iOS, ensure that the iOS deployment target is appropriately set in `ios/Podfile`.

4. **Obtain API Keys or Credentials**:  
   Contact the project administrator to get the necessary API keys and add them to a secure configuration file. For example:
    - Use `.env` files with the `flutter_dotenv` package.
    - Or configure them directly in platform-specific files if required, e.g., `local.properties` for Android.

5. **Run the Application**:  
   Start the project on your desired emulator or physical device:
   ```bash
   flutter run
   ```

6. **Optional (Debugging)**:  
   Enable developer tools such as Flutter DevTools for debugging and performance profiling:
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```