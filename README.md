# Implementing Two-Way Communication Using Watch Connectivity
Transfer data between a watchOS app and its paired iOS app to synchronize their states.

## Overview
Some watch apps heavily rely on their paired iOS app to perform complicated calculations or present rich content, and need to exchange data with the iOS companion even when an internet connection is unavailable. The Watch Connectivity framework provides convenient APIs to implement two-way communication between paired apps. This sample shows the subtle differences between these APIs and demonstrates how to handle Watch Connectivity background tasks.

## Configure the Sample Code Project
Before building the sample app, perform the following steps in Xcode:
1. In the General pane of the `SimpleWatchConnectivity` target, update the Bundle Identifier field with a new identifier.
2. In the Signing & Capabilities pane, select the applicable team from the Team drop-down menu to let Xcode automatically manage the provisioning profile. See [Assign a project to a team](https://help.apple.com/xcode/mac/current/#/dev23aab79b4) for details.
3. Similarly, update the bundle identifier and developer team for the WatchKit app and WatchKit Extension targets. The bundle identifiers must be `<iOS app bundle identifier>.watchkitapp` and `<iOS app bundle identifier>.watchkitapp.watchkitextension`, respectively.
4. Open the `Info.plist` file of the WatchKit app target and update the value of `WKCompanionAppBundleIdentifier` key with the new iOS app bundle identifier.
5. Open the `Info.plist` file of the WatchKit Extension target and update the value of the `NSExtension > NSExtensionAttributes > WKAppBundleIdentifier` key with the new WatchKit app bundle identifier.

## Transfer Data Using Watch Connectivity
The Watch Connectivity framework provides APIs to do the following tasks:
- Update application contexts.
- Send messages.
- Transfer user info and manage the outstanding transfers.
- Transfer files, view transfer progress, and manage the outstanding transfers.
- Update current complications from iOS apps.

The APIs all accept a dictionary and transfer it between apps but have notable differences. [`updateApplicationContext(_:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)) sends a dictionary, which is typically a piece of app conext data, to the counterpart app and replaces the existing data if any.
 [`transferUserInfo(_:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)) transfers a dictionary as well, but it ensures that the delivery happens. If an app transfers multiple dictionaries in a short interval, the system queues them up and deliver them in the same order. 
 [`sendMessage(_:replyHandler:errorHandler:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)) sends a dictionary immediately and can return an error if the sending fails. 
 
 When sending a message, apps can optionally provide a reply handler for receiving the counterpart's response. The reply handle runs asynchronously on a background thread and should return quickly to avoid time out. Sending a message from a watchOS app wakes up its paired iOS app if it's reachable.

## Update Active Complications from iOS apps
To demonstrate current complication user information transfer, this sample provides a complication that shows a random number. Use these steps to activate the complication:
1. Choose a Modular watch face on the watch.
2. Press the watch face to show the customization screen, tap the Edit button, then swipe right to show the configuration screen. 
3. Tap the tall body area, then rotate the digital crown to find the `SimpleWatchConnectivity` complication.
4. Press the digital crown and tap the screen to go back and finish the configuration.

To update the complication from the iOS app, this sample calls `transferCurrentComplicationUserInfo` on the iOS side if the complication is active. The system allows 50 transfers of this kind per day, and apps can use [`remainingComplicationUserInfoTransfers`](https://developer.apple.com/documentation/watchconnectivity/wcsession/remainingcomplicationuserinfotransfers) to retrieve the number of remaining times.

``` swift
if WCSession.default.isComplicationEnabled {
    let userInfoTranser = WCSession.default.transferCurrentComplicationUserInfo(userInfo)
```

On the watch side, this sample calls `reloadTimeline` to update the complication.

``` swift
let server = CLKComplicationServer.sharedInstance()
if let complications = server.activeComplications {
    for complication in complications {
        // Call this method sparingly.
        // Use extendTimeline(for:) instead when the timeline is still valid.
        server.reloadTimeline(for: complication)
    }
}
```

## Handle Watch Connectivity Background Tasks
Apps must complete `WKWatchConnectivityRefreshBackgroundTask`. Otherwise, tasks keep consuming the background executing time until time runs out of the budget and the app crashes. This sample retains the tasks in an array and complete them when:

- The app finishes handling the tasks.
- The current `WCSession` turns to a state other than [`.activated`](https://developer.apple.com/documentation/watchconnectivity/wcsessionactivationstate/activated).
- [`hasContentPending`](https://developer.apple.com/documentation/watchconnectivity/wcsession/hascontentpending) flips `false`, which indicates that there's no pending data (received prior to `WCSession` activation) waiting for processing.

The following code completes the tasks at the end of the [`handle(_:)`](https://developer.apple.com/documentation/watchkit/wkextensiondelegate/1650877-handle) method of the extension delegate.

``` swift
func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
        if let wcTask = task as? WKWatchConnectivityRefreshBackgroundTask {
            wcBackgroundTasks.append(wcTask)
            Logger.shared.append(line: "\(#function):\(wcTask.description) was appended!")
        } else {
            task.setTaskCompletedWithSnapshot(false)
            Logger.shared.append(line: "\(#function):\(task.description) was completed!")
        }
    }
    completeBackgroundTasks()
}
```

The following code completes the tasks in the other cases.
``` swift
activationStateObservation = WCSession.default.observe(\.activationState) { _, _ in
    DispatchQueue.main.async {
        self.completeBackgroundTasks()
    }
}
hasContentPendingObservation = WCSession.default.observe(\.hasContentPending) { _, _ in
    DispatchQueue.main.async {
        self.completeBackgroundTasks()
    }
}
```

Debugging background tasks can be tricky because watchOS apps typically don't run for a long time. After users stop using an app and lower their wrist, watchOS suspends the app. When watchOS triggers a background task for an app, the app can be in the suspended state, so the system needs to wake it up (or launch it). Using Xcode to run an app prevents the system from proceeding with the suspending process, which leads to a discrepancy between the debugging environment and the final user environment. To avoid this discrepancy, debug the app by launching it directly from the home screen and analyzing the app logs. For debugging, this sample uses the [`Logger`](Shared/Logger.swift) class to write logs into a file and transfers it to the iOS app when users tap the file transfer button on the watch app.
