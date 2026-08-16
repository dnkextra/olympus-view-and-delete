# Olympus View Privacy Policy

> Effective date: August 15, 2026. Olympus View is an unofficial camera utility. It has no user accounts, advertising, developer analytics backend, or developer-operated cloud photo storage. Camera photos and camera WiFi credentials are handled locally on the user's device. The Android QR scanner uses Google ML Kit, which may send Google technical diagnostics and usage metrics as described below.

## Developer and scope

This policy applies to the Olympus View application published by the `dpolarov` project maintainer.

Olympus View is not affiliated with or endorsed by OM Digital Solutions, Olympus, or OM System.

Project repository: https://github.com/dpolarov/olympus-view-and-delete

## Camera connection and nearby WiFi

Olympus View connects directly to a compatible camera over the camera's local WiFi network.

On modern Android versions the app requests Nearby devices / Nearby WiFi access for this purpose. On Android 12L and older, Android requires location permission for the WiFi APIs used by the app.

Olympus View does not use nearby WiFi information to derive, store, or transmit the user's physical location.

## Camera and QR scanning

Camera permission is used only to scan a camera QR code containing connection information. QR image input and recognized barcode contents are processed on the device and are not sent by Olympus View to the developer.

On Android, QR recognition is provided through Google ML Kit via the Mobile Scanner library. According to Google's ML Kit documentation, image recognition processing happens on-device and the image and recognition output are not sent to Google. ML Kit may send Google technical data such as device and application information, per-installation identifiers, performance metrics, API configuration, feature events, and error codes for diagnostics and usage analytics. Google states that this data is encrypted in transit and is not transferred by ML Kit to third parties.

## Saved camera credentials

If the user saves or reconnects to a camera, Olympus View can store the camera SSID, WiFi password, security type, optional Bluetooth metadata, camera name, and last connection time in the app's local storage.

This information is used only to reconnect to the camera and is not sent to the Olympus View developer. Android application backup is disabled to reduce the chance of camera credentials being copied to cloud backup.

Saved camera entries can be removed from the connection screen. Uninstalling the application removes its app-local data.

## Photos and files

Photos, thumbnails, previews, and file metadata are transferred directly between the camera and the user's device over the camera's local network.

Olympus View does not upload them to a developer-operated server or cloud service. Downloaded files are saved to user-accessible device storage. Temporary previews and thumbnails may be cached locally to improve performance.

## Network communication

Compatible cameras expose a local HTTP interface, normally at `192.168.0.10`.

The Android app permits cleartext HTTP only for that local camera address; unrelated network traffic is not granted a general cleartext exception.

## Advertising and accounts

Olympus View contains no advertising SDK and does not require or provide a user account.

## Project website and feedback form

The Olympus View project website has a separate feedback data flow. If a visitor voluntarily submits the website feedback form, the supplied name, email address, and message are transmitted to Formspree so that the maintainer can receive and respond to the message.

The website feedback form is not embedded in the Android app and is not required to use Olympus View.

## Retention and deletion

App-local camera history and caches remain on the device until the user removes them, clears application data, or uninstalls the application.

Olympus View does not maintain a server-side account database.

To request deletion of information previously sent through the project website feedback form, use the feedback form and identify the request as a privacy/deletion request.

## Children

Olympus View is a general-purpose camera utility and is not specifically directed to children.

## Changes to this policy

This policy may be updated when application functionality, third-party SDK behavior, or legal requirements change. The effective date at the top indicates the current version.

## Contact

Privacy questions and deletion requests can be sent using the project feedback form:

https://dpolarov.github.io/olympus-view-and-delete/#feedback-en

The source code and issue tracker are available at:

https://github.com/dpolarov/olympus-view-and-delete
