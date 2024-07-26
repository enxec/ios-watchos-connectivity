/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A SwiftUI view that shows a command.
*/

import SwiftUI
import Combine
import WatchConnectivity

extension NotificationCenter {
    var dataDidFlowPublisher: Publishers.ReceiveOn<NotificationCenter.Publisher, DispatchQueue> {
        return publisher(for: .dataDidFlow).receive(on: .main)
    }
}

struct CommandView: View, TestDataProvider, SessionCommands {
    let command: Command
    @State private var fileTransferObservers = FileTransferObservers()

    @State private var message = "No activity"
    @State private var textColor: Color = .secondary
    @State private var showOutstandingTransfersSheet = false
    @Binding var selectedTab: Command
        
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                let outstandingTransferCount = outstandingTransferCount()
                
                Button(action: {
                    showOutstandingTransfersSheet = (outstandingTransferCount > 0)
                }) {
                    Text(message)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .foregroundColor(textColor)
                }
                .buttonBorderShape(.roundedRectangle(radius: 8.0))
                
                if outstandingTransferCount > 0 {
                    Circle()
                        .fill(.blue)
                        .frame(width: 25, height: 25)
                        .overlay {
                            Text("\(outstandingTransferCount)")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                }
            }
            
            Button(command.rawValue) {
                runCommand(command: command)
            }
            .foregroundColor(textColor)
        }
        .onAppear() {
            updateWithInitialState()
        }
        .onReceive(NotificationCenter.default.dataDidFlowPublisher) { notification in
            dataDidFlow(notification)
        }
        .sheet(isPresented: $showOutstandingTransfersSheet) {
            if command == .transferFile {
                FileTransfersView(command: command)
            } else {
                UserInfoTransfersView(command: command)
            }
        }
    }
}

/**
 Update UI.
 */
extension CommandView {
    /**
     Retrieve the current outstanding transfer count.
     The watchOS side doesn't support .transferCurrentComplicationUserInfo.
     */
    private func outstandingTransferCount() -> Int {
        if command == .transferUserInfo {
            return WCSession.default.outstandingUserInfoTransfers.count
        } else if command == .transferFile {
            return WCSession.default.outstandingFileTransfers.count
        }
        return 0
    }
    
    /**
     Update the view with the initial session state.
     For .updateAppContext, retrieve the app context, if any, and update the UI.
     For .transferFile and .transferUserInfo, log the outstanding transfers, if any.
     The watchOS side doesn't support .transferCurrentComplicationUserInfo.
     */
    private func updateWithInitialState() {
        if command == .updateAppContext {
            let timedColor = WCSession.default.receivedApplicationContext
            if !timedColor.isEmpty {
                var commandStatus = CommandStatus(command: command, phrase: .received)
                commandStatus.timedColor = TimedColor(timedColor)
                updateUI(with: commandStatus)
            }
            return
        }
        
        var outstandingTransfers: [any SessionTransfer] = []
        if command == .transferFile {
            outstandingTransfers = WCSession.default.outstandingFileTransfers
        } else if command == .transferUserInfo {
            outstandingTransfers = WCSession.default.outstandingUserInfoTransfers
        }
        if let firstTransfer = outstandingTransfers.first {
            var commandStatus = CommandStatus(command: command, phrase: .transferring)
            commandStatus.timedColor = firstTransfer.timedColor
            logOutstandingTransfers(for: commandStatus, outstandingCount: outstandingTransfers.count)
        }
    }
    
    /**
     Update the user interface with the command status.
     There isn't a timed color when the app initially loads the interface.
     */
    private func updateUI(with commandStatus: CommandStatus, errorMessage: String? = nil) {
        guard let timedColor = commandStatus.timedColor else {
            message = "No data transferred"
            return
        }
        textColor = Color(uiColor: timedColor.color)
        /**
         If there's an error, show the message and return.
         */
        if let errorMessage = errorMessage {
            message = ("! \(errorMessage)")
            return
        }
        /**
         Observe the file transfer if the phrase is "transferring."
         Un-observe a file transfer if the phrase is "finished."
         */
        if let fileTransfer = commandStatus.fileTransfer, commandStatus.command == .transferFile {
            if commandStatus.phrase == .finished {
                fileTransferObservers.unobserve(fileTransfer)
            } else if commandStatus.phrase == .transferring {
                fileTransferObservers.observe(fileTransfer) { _ in
                    self.textColor = Color(uiColor: fileTransfer.timedColor.color)
                    self.logProgress(for: commandStatus)
                }
            }
        }
        /**
         Log the outstanding file transfers, if any.
         */
        if commandStatus.command == .transferFile {
            let transferCount = WCSession.default.outstandingFileTransfers.count
            if transferCount > 0 {
                return logOutstandingTransfers(for: commandStatus, outstandingCount: transferCount)
            }
        }
        /**
         Log the outstanding UserInfo transfers, if any.
         */
        if commandStatus.command == .transferUserInfo {
            let transferCount = WCSession.default.outstandingUserInfoTransfers.count
            if transferCount > 0 {
                return logOutstandingTransfers(for: commandStatus, outstandingCount: transferCount)
            }
        }
        message = commandStatus.phrase.rawValue + " at\n" + timedColor.timeStamp
    }
    
    /**
     Log the outstanding transfer information, if any.
     */
    private func logOutstandingTransfers(for commandStatus: CommandStatus, outstandingCount: Int) {
        var text = commandStatus.phrase.rawValue + " at\n" + commandStatus.timedColor!.timeStamp
        text += "\nOutstanding: \(outstandingCount)"
        message = text
    }
    
    /**
     Log the current file transfer progress. The app captures the command status when observing the file transfer.
     */
    private func logProgress(for commandStatus: CommandStatus) {
        guard let fileTransfer = commandStatus.fileTransfer else { return }
        
        let fileName = fileTransfer.file.fileURL.lastPathComponent
        let progress = fileTransfer.progress.localizedDescription ?? "No progress"
        message = commandStatus.phrase.rawValue + "\n" + fileName + "\n" + progress
    }
}

/**
 Button actions.
 */
extension CommandView {
    private func runCommand(command: Command) {
        switch command {
        case .updateAppContext:
            updateAppContext(appContext)
        case .sendMessage:
            sendMessage(message)
        case .sendMessageData:
            sendMessageData(messageData)
        case .transferUserInfo:
            transferUserInfo(userInfo)
        case .transferFile:
            transferFile(file, metadata: fileMetaData)
        case .transferCurrentComplicationUserInfo:
            transferCurrentComplicationUserInfo(currentComplicationInfo)
        }
    }
}

/**
 Notification handler.
 Update the UI when getting a .dataDidFlow notification.
 */
extension CommandView {
    private func dataDidFlow(_ notification: Notification) {
        guard let commandStatus = notification.object as? CommandStatus else { return }
        /**
         If the data is from the current channel, update the color and timestamp.
         */
        if commandStatus.command == command {
            updateUI(with: commandStatus, errorMessage: commandStatus.errorMessage)
            return
        }
        /**
         Switch to the current tab, if necessary.
         */
        if selectedTab != commandStatus.command {
            selectedTab = commandStatus.command
        }
    }
}
