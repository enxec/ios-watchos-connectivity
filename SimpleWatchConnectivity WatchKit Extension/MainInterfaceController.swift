/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main interface controller of the WatchKit extension.
*/

import Foundation
import WatchKit
import WatchConnectivity

// identifier is the page Interface Controller identifier.
// context is the page context or the action button title.
//
struct ControllerID {
    static let mainInterfaceController = "MainInterfaceController"
}

class MainInterfaceController: WKInterfaceController, TestDataProvider, SessionCommands {
    
    @IBOutlet weak var statusGroup: WKInterfaceGroup!
    @IBOutlet var statusLabel: WKInterfaceLabel!
    @IBOutlet var commandButton: WKInterfaceButton!

    // Retain the controllers so there's no need to reload root controllers for every switch.
    //
    static var instances = [MainInterfaceController]()
    private var command: Command!
    
    private let fileTransferObservers = FileTransferObservers()
    
    // context == nil: Load the pages using reloadRootController.
    // context != nil: Load the pages and cache the controller instances to switch pages more smoothly.
    //
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        if let context = context as? CommandStatus {
            command = context.command
            updateUI(with: context)
            type(of: self).instances.append(self)
        } else {
            statusLabel.setText("Activating...")
            reloadRootController()
        }
        
        // Install notification observer.
        //
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of: self).dataDidFlow(_:)),
            name: .dataDidFlow, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of: self).activationDidComplete(_:)),
            name: .activationDidComplete, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of: self).reachabilityDidChange(_:)),
            name: .reachabilityDidChange, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func willActivate() {
        super.willActivate()
        guard command != nil else { return } // Do nothing for first-time loading.
        
        // For .updateAppContext, retrieve the app context, if any, and update the UI.
        // For .transferFile and .transferUserInfo, log the outstanding transfers, if any.
        //
        if command == .updateAppContext {
            let timedColor = WCSession.default.receivedApplicationContext
            if timedColor.isEmpty == false {
                var commandStatus = CommandStatus(command: command, phrase: .received)
                commandStatus.timedColor = TimedColor(timedColor)
                updateUI(with: commandStatus)
            }
        } else if command == .transferFile {
            let transferCount = WCSession.default.outstandingFileTransfers.count
            if transferCount > 0 {
                let commandStatus = CommandStatus(command: .transferFile, phrase: .finished)
                logOutstandingTransfers(for: commandStatus, outstandingCount: transferCount)
            }
        } else if command == .transferUserInfo {
            let transferCount = WCSession.default.outstandingUserInfoTransfers.count
            if transferCount > 0 {
                let commandStatus = CommandStatus(command: .transferUserInfo, phrase: .finished)
                logOutstandingTransfers(for: commandStatus, outstandingCount: transferCount)
            }
        }
        
        // Update the status group background color.
        //
        if command != .transferFile && command != .transferUserInfo {
            statusGroup.setBackgroundColor(.black)
        }
    }
    
    // Load paged-based UI.
    // Use the timed color if the current context provides.
    //
    private func reloadRootController(with currentContext: CommandStatus? = nil) {
        let commands: [Command] = [.updateAppContext, .sendMessage, .sendMessageData,
                                   .transferFile, .transferUserInfo,
                                   .transferCurrentComplicationUserInfo]
        var contexts = [CommandStatus]()
        for aCommand in commands {
            var commandStatus = CommandStatus(command: aCommand, phrase: .finished)
            
            if let currentContext = currentContext, aCommand == currentContext.command {
                commandStatus.phrase = currentContext.phrase
                commandStatus.timedColor = currentContext.timedColor
            }
            contexts.append(commandStatus)
        }
        
        let names = Array(repeating: ControllerID.mainInterfaceController, count: contexts.count)

        WKInterfaceController.reloadRootControllers(withNamesAndContexts: Array( zip(names, contexts as [AnyObject]) ))
    }
    
    // .dataDidFlow notification handler. Update the UI with the command status.
    //
    @objc
    func dataDidFlow(_ notification: Notification) {
        guard let commandStatus = notification.object as? CommandStatus else { return }
        
        // If the data is from the current channel, simply update color and time stamp, then return.
        //
        if commandStatus.command == command {
            updateUI(with: commandStatus, errorMessage: commandStatus.errorMessage)
            return
        }
        
        // Move the screen to the page matching the data channel, then update the color and time stamp.
        //
        if let index = type(of: self).instances.firstIndex(where: { $0.command == commandStatus.command }) {
            let controller = MainInterfaceController.instances[index]
            controller.becomeCurrentPage()
            controller.updateUI(with: commandStatus, errorMessage: commandStatus.errorMessage)
        }
    }

    // .activationDidComplete notification handler.
    //
    @objc
    func activationDidComplete(_ notification: Notification) {
        print("\(#function): activationState:\(WCSession.default.activationState.rawValue)")
    }
    
    // .reachabilityDidChange notification handler.
    //
    @objc
    func reachabilityDidChange(_ notification: Notification) {
        print("\(#function): isReachable:\(WCSession.default.isReachable)")
    }
    
    // Do the command associated with the current page.
    //
    @IBAction func commandAction() {
        guard let command = command else { return }
        
        switch command {
        case .updateAppContext: updateAppContext(appContext)
        case .sendMessage: sendMessage(message)
        case .sendMessageData: sendMessageData(messageData)
        case .transferUserInfo: transferUserInfo(userInfo)
        case .transferFile: transferFile(file, metadata: fileMetaData)
        case .transferCurrentComplicationUserInfo: transferCurrentComplicationUserInfo(currentComplicationInfo)
        }
    }
    
    // Show the outstanding transfer UI for .transferFile and .transferUserInfo.
    //
    @IBAction func statusAction() {
        if command == .transferFile {
            presentController(withName: ControllerID.fileTransfersController, context: command)
        } else if command == .transferUserInfo {
            presentController(withName: ControllerID.userInfoTransfersController, context: command)
        }
    }
}

extension MainInterfaceController { // MARK: - Update status view.
    
    // Update the user interface with the command status.
    // There isn't a timed color when the app initially loads the interface controller.
    //
    private func updateUI(with commandStatus: CommandStatus, errorMessage: String? = nil) {
        guard let timedColor = commandStatus.timedColor else {
            statusLabel.setText("")
            commandButton.setTitle(commandStatus.command.rawValue)
            return
        }
        
        let title = NSAttributedString(string: commandStatus.command.rawValue,
                                       attributes: [.foregroundColor: timedColor.color])
        commandButton.setAttributedTitle(title)
        statusLabel.setTextColor(timedColor.color)
        
        // If there's an error, show the message and return.
        //
        if let errorMessage = errorMessage {
            statusLabel.setText("! \(errorMessage)")
            return
        }
        
        // Observe the file transfer if the phrase is "transferring."
        // Un-observe a file transfer if the phrase is "finished."
        //
        if let fileTransfer = commandStatus.fileTransfer, commandStatus.command == .transferFile {
            if commandStatus.phrase == .finished {
                fileTransferObservers.unobserve(fileTransfer)
            } else if commandStatus.phrase == .transferring {
                fileTransferObservers.observe(fileTransfer) { _ in
                    self.logProgress(for: commandStatus)
                }
            }
        }
        
        // Log the outstanding file transfers, if any.
        //
        if commandStatus.command == .transferFile {
            let transferCount = WCSession.default.outstandingFileTransfers.count
            if transferCount > 0 {
                return logOutstandingTransfers(for: commandStatus, outstandingCount: transferCount)
            }
        }
        
        // Log the outstanding UserInfo transfers, if any.
        //
        if commandStatus.command == .transferUserInfo {
            let transferCount = WCSession.default.outstandingUserInfoTransfers.count
            if transferCount > 0 {
                return logOutstandingTransfers(for: commandStatus, outstandingCount: transferCount)
            }
        }
        
        statusLabel.setText( commandStatus.phrase.rawValue + " at\n" + timedColor.timeStamp)
    }
    
    // Log the outstanding transfer information, if any.
    //
    private func logOutstandingTransfers(for commandStatus: CommandStatus, outstandingCount: Int) {
        if commandStatus.phrase == .transferring {
            var text = commandStatus.phrase.rawValue + " at\n" + commandStatus.timedColor!.timeStamp
            text += "\nOutstanding: \(outstandingCount)\n Tap to view"
            return statusLabel.setText(text)
        }
        
        if commandStatus.phrase == .finished {
            return statusLabel.setText("Outstanding: \(outstandingCount)\n Tap to view")
        }
    }
    
    // Log the file transfer progress. The app captures the command status when observing the file transfer.
    //
    private func logProgress(for commandStatus: CommandStatus) {
        guard let fileTransfer = commandStatus.fileTransfer else { return }
        
        let fileName = fileTransfer.file.fileURL.lastPathComponent
        let progress = fileTransfer.progress.localizedDescription ?? "No progress"
        statusLabel.setText(commandStatus.phrase.rawValue + "\n" + fileName + "\n" + progress)
    }
}
