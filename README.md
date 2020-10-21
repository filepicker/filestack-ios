# Filestack iOS SDK

<a href="https://www.filestack.com"><img src="https://www.filestack.com/docs/images/fs-logo-dark.svg" align="left" hspace="10" vspace="6"></a>
This is the official Swift iOS for Filestack — API and content management system that makes it easy to add powerful file uploading and transformation capabilities to any web or mobile application.

## Resources

* [Filestack](https://www.filestack.com)
* [Documentation](https://www.filestack.com/docs)
* [API Reference](https://filestack.github.io/filestack-ios/)

## Requirements

* Xcode 11+ (*Xcode 12+ required for SPM support*)
* Swift 4.2+ / Objective-C
* iOS 11.0+

## Installing

### CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Cocoa projects. You can install it with the following command:

`$ gem install cocoapods`

To integrate Filestack into your Xcode project using CocoaPods, specify it in your `Podfile`:

```
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '11.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Filestack', '~> 2.5.1'
end
```

Then, run the following command:

`$ pod install`

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```
$ brew update
$ brew install carthage
```

To integrate Filestack into your Xcode project using Carthage, specify it in your `Cartfile`:

`github "filestack/filestack-ios" ~> 2.5.1`

Run `carthage update` to build the framework and drag the built `Filestack.framework` into your Xcode project. Additionally, add `Filestack.framework`, `FilestackSDK.framework`, `Alamofire.framework`, and `Zip.framework` to the embedded frameworks build phase of your app's target.

### Swift Package Manager

Add `https://github.com/filestack/filestack-ios.git` as a [Swift Package Manager](https://swift.org/package-manager/) dependency to your Xcode project.

Alternatively, if you are adding `Filestack` to your own Swift Package, declare the dependency in your `Package.swift`:

```swift
dependencies: [
    .package(name: "Filestack", url: "https://github.com/filestack/filestack-ios.git", .upToNextMajor(from: "2.5.1"))
]
```

### Manually

#### Embedded Framework

Open up Terminal, cd into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

`$ git init`

Add Filestack and its dependencies as git submodules by running the following commands:

```shell
$ git submodule add https://github.com/filestack/filestack-ios.git
$ git submodule add https://github.com/filestack/filestack-swift.git
$ git submodule add https://github.com/Alamofire/Alamofire.git
$ git submodule add https://github.com/marmelroy/Zip.git
```

Open the new `filestack-ios` folder, and drag the `Filestack.xcodeproj` into the Project Navigator of your application's Xcode project.

It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.
Select the `Filestack.xcodeproj` in the Project Navigator and verify the deployment target matches that of your application target.

Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.

In the tab bar at the top of that window, open the "General" panel.

Click on the + button under the "Embedded Binaries" section and choose the `Filestack.framework` for iOS.

Repeat the same process for adding `Alamofire`, `FilestackSDK`, and `Zip` dependent frameworks.

## Usage

### Importing required frameworks

Any source files that need to use the Filestack iOS SDK should import the `Filestack` and `FilestackSDK` frameworks:

```swift
import Filestack
import FilestackSDK
```

### Instantiating a Filestack object

```swift
// Initialize a `Policy` with the expiry time and permissions you need.
let oneDayInSeconds: TimeInterval = 60 * 60 * 24 // expires tomorrow
let policy = Policy(// Set your expiry time (24 hours in our case)
                    expiry: Date(timeIntervalSinceNow: oneDayInSeconds),
                    // Set the permissions you want your policy to have
                    call: [.pick, .read, .store])

// Initialize a `Security` object by providing a `Policy` object and your app secret.
// You can find and/or enable your app secret in the Developer Portal.
guard let security = try? Security(policy: policy, appSecret: "YOUR-APP-SECRET") else {
    return
}

// Create `Config` object.
let config = Filestack.Config()

// Make sure to assign a callback URL scheme that is handled by your app.
config.callbackURLScheme = "filestackdemo"

let client = Filestack.Client(apiKey: "YOUR-API-KEY", security: security, config: config)
```

### Uploading local files

```swift
let localURL = URL(string: "file:///an-app-sandbox-friendly-local-url")!

let uploader = client.upload(using: localURL, uploadProgress: { (progress) in
    // Here you may update the UI to reflect the upload progress.
    print("progress = \(String(describing: progress))")
}) { (response) in
    // Try to obtain Filestack handle
    if let json = response?.json, let handle = json["handle"] as? String {
        // Use Filestack handle
    } else if let error = response?.error {
        // Handle error
    }
}
```

### Uploading photos and videos from the Photo Library or Camera

```swift
// The view controller that will be presenting the image picker.
let presentingViewController = self

// The source type (e.g. `.camera`, `.photoLibrary`)
let sourceType: UIImagePickerControllerSourceType = .camera

let uploader = client.uploadFromImagePicker(viewController: presentingViewController, sourceType: sourceType, uploadProgress: { (progress) in
    // Here you may update the UI to reflect the upload progress.
    print("progress = \(String(describing: progress))")
}) { (response) in
    // Try to obtain Filestack handle
    if let json = response?.json, let handle = json["handle"] as? String {
        // Use Filestack handle
    } else if let error = response?.error {
        // Handle error
    }
}
```

### Uploading files from device, iCloud Drive or another third-party cloud provider

```swift
// The view controller that will be presenting the image picker.
let presentingViewController = self

let uploader = client.uploadFromDocumentPicker(viewController: presentingViewController, uploadProgress: { (progress) in
    // Here you may update the UI to reflect the upload progress.
    print("progress = \(String(describing: progress))")
}) { (response) in
    // Try to obtain Filestack handle
    if let json = response?.json, let handle = json["handle"] as? String {
        // Use Filestack handle
    } else if let error = response?.error {
        // Handle error
    }
}
```

In all the previous uploading examples, an upload may be cancelled at anytime by calling `cancel()` on the `Uploader`:

```swift
uploader.cancel()
```

### Listing contents from a cloud provider

```swift
client.folderList(provider: .googleDrive, path: "/", pageToken: nil) { response in
    if let error = response.error {
        // Handle error
        return
    }

    if let contents = response.contents {
        // Contents received — do something with them.
        print("Received \(contents.count) entries.")
    }

    if let nextToken = response.nextToken {
    	 // More contents are available — to retrieve next page, pass this `nextToken` as a parameter in the `folderList` function.
    } else {
    	 // No more contents available — we are done.
    }
}
```

### Storing contents from a cloud provider into a store location

```swift
// Store options for your uploaded files.
// Here we are saying our storage location is S3 and access for uploaded files should be public.
let storeOptions = StorageOptions(location: .s3, access: .public)

client.store(provider: .googleDrive, path: "/some-large-image.jpg", storeOptions: storeOptions) { (response) in
    if let error = response.error {
        // Handle error
        return
    }

    if let contents = response.contents {
        // Contents received describing the request's result.
    }
}
```

Please make sure to authenticate against the cloud provider first by using the `folderList` function before calling `store`.


### Launching picker UI

This is a code fragment broken into pieces taken from the demo app (included in this repository) describing the process of launching the picker UI using some of the most relevant config options:

#### 1. Setting up Policy and Security objects

```swift
// In case your Filestack account has security enabled, you will need to instantiate a `Security` object.
// We can do this by either configuring a `Policy` and instantiating a `Security` object by passing
// the `Policy` and an `appSecret`, or by instantiating a `Security` object directly by passing an already
// encoded policy together with its corresponding signature — in this example, we will use the 1st method.

// Create `Policy` object with an expiry time and call permissions.
let policy = Policy(expiry: .distantFuture,
                    call: [.pick, .read, .stat, .write, .writeURL, .store, .convert, .remove, .exif])

// Create `Security` object based on our previously created `Policy` object and app secret obtained from
// https://dev.filestack.com/.
guard let security = try? Security(policy: policy, appSecret: "YOUR-APP-SECRET-HERE") else {
    fatalError("Unable to instantiate Security object.")
}
```

#### 2. Setting up Config object

```swift
// Create `Config` object.
// IMPORTANT: - Make sure to assign an app scheme URL that matches the one(s) configured in your info.plist
let config = Filestack.Config.builder
  .with(callbackURLScheme: "YOUR-APP-URL-SCHEME")
  .with(videoQuality: .typeHigh)
  .with(imageURLExportPreset: .current)
  .with(maximumSelectionLimit: 10)
  .withEditorEnabled()
  .with(availableCloudSources: [.dropbox, .googledrive, .googlephotos, .customSource])
  .with(availableLocalSources: [.camera])
  .build()
```

#### 3. Setting up Client object

```swift
// Instantiate the Filestack `Client` by passing an API key obtained from https://dev.filestack.com/,
// together with a `Security` and `Config` object.
// If your account does not have security enabled, then you can omit this parameter or set it to `nil`.
let client = Filestack.Client(apiKey: "YOUR-API-KEY-HERE", security: security, config: config)
```

#### 4. Instantiating the picker with custom storage options

```swift
// Store options for your uploaded files.
// Here we are saying our storage location is S3 and access for uploaded files should be public.
let storeOptions = StorageOptions(location: .s3, access: .public)

// Instantiate picker by passing the `StorageOptions` object we just set up.
let picker = client.picker(storeOptions: storeOptions)
```

#### 5. Setting the picker's delegate

```swift
// Optional. Set the picker's delegate.
picker.pickerDelegate = self
```

And implement the `PickerNavigationControllerDelegate` protocol in your view controller, i.e.:

```swift
extension ViewController: PickerNavigationControllerDelegate {
    /// Called when the picker finishes storing a file originating from a cloud source into the destination storage location.
    func pickerStoredFile(picker: PickerNavigationController, response: StoreResponse) {
        if let contents = response.contents {
            // Our cloud file was stored into the destination location.
            print("Stored file response: \(contents)")
        } else if let error = response.error {
            // The store operation failed.
            print("Error storing file: \(error)")
        }
    }

    /// Called when the picker finishes uploading a file originating from the local device into the destination storage location.
    func pickerUploadedFile(picker: PickerNavigationController, response: JSONResponse?) {
        if let contents = response?.json {
            // Our local file was stored into the destination location.
            print("Uploaded file response: \(contents)")
        } else if let error = response?.error {
            // The upload operation failed.
            print("Error uploading file: \(error)")
        }
    }

    /// Called when the picker reports progress during a file or set of files being uploaded.
    func pickerReportedUploadProgress(picker: PickerNavigationController, progress: Float) {
        print("Picker \(picker) reported upload progress: \(progress)")
    }
}
```

#### 6. Presenting the picker on the screen

```swift
yourViewController.present(picker, animated: true)
```

#### 7. Enabling background upload support

Starting in FilestackSDK `2.3`, background upload support is available. In order to use it in `Filestack` for file uploads, simply add the following to your code:

```swift
// Set `UploadService.shared.useBackgroundSession` to true to allow uploads in the background.
FilestackSDK.UploadService.shared.useBackgroundSession = true
```

## Demo

Check the demo app included in this repository showcasing all the topics discussed above.

## Versioning

Filestack iOS SDK follows the [Semantic Versioning](http://semver.org/).

## Issues

If you have problems, please create a [Github Issue](https://github.com/filestack/filestack-ios/issues).

## Contributing

Please see [CONTRIBUTING.md](https://github.com/filestack/filestack-ios/blob/master/CONTRIBUTING.md) for details.

## Credits

Thank you to all the [contributors](https://github.com/filestack/filestack-ios/graphs/contributors).
