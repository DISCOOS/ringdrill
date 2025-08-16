# RingDrill App

Efficient station-based training. Organize, run and track drills with ease.

[![Google Play](https://playbadges.pavi2410.me/badge/full?id=org.discoos.ringdrill)](https://play.google.com/store/apps/details?id=org.discoos.ringdrill)
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

4. **Generate Code Using Build Runner**:  
   Generate any required code for the project by running:
   ```bash
   make build
   ```

5. **Enable Build Runner Watch Mode (Optional)**:  
   To automatically rebuild generated code when making changes, you can run:
   ```bash
   make watch
   ```

6. **Create Release Builds**:  
   For generating an Android release build using Shorebird, execute:
   ```bash
   make release-android
   ```

7. **Patch Android Builds** (*Optional*):  
   If deploying incremental patch updates for Android, run:
   ```bash
   make patch-android
   ```

8. **Run the Application**:  
   Start the project on your desired emulator or physical device:
   ```bash
   flutter run
   ```
   
9. **Run the Admin CLI**:
   To activate: 
    ```bash
   dart pub global activate -s path .
    ```
   See usage for additional information:
    ```bash
   ringdrill -h
    ```