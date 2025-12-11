# API Key Setup Instructions

To run the application, you need to provide your own Google Maps API key. This is handled via a `Secrets.xcconfig` file that is **not** checked into version control.

## Steps

1.  **Navigate to the correct directory:**
    Open your terminal and go to the `ios/Flutter/` directory inside the project.
    ```sh
    cd Project-PaceLifter/ios/Flutter/
    ```

2.  **Create the `Secrets.xcconfig` file:**
    Create a new file named `Secrets.xcconfig`. You can do this with the `touch` command:
    ```sh
    touch Secrets.xcconfig
    ```

3.  **Add your API Key:**
    Open the newly created `Secrets.xcconfig` file in a text editor and add the following line, replacing `YOUR_API_KEY_HERE` with your actual Google Maps API key for iOS.

    ```
    GOOGLE_MAPS_API_KEY = YOUR_API_KEY_HERE
    ```

4.  **Save the file.**

After completing these steps, you can build and run the Flutter application for iOS. The build process will now correctly embed your API key without exposing it in the source code.
