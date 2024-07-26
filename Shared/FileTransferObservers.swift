/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Manages the observation of the file transfer progress.
*/

import Foundation
import WatchConnectivity

@Observable
class FileTransferObservers {
    
    // Hold the observations and file transfers.
    // The system removes KVO automatically after releasing the observations.
    //
    private var fileTransferObervations = [WCSessionFileTransfer: NSKeyValueObservation]()
    private(set) var progresssDescriptions = [WCSessionFileTransfer: String]()

    private var observations: [NSKeyValueObservation] {
        return Array(fileTransferObervations.values)
    }
    
    var fileTransfers: [WCSessionFileTransfer] {
        return Array(fileTransferObervations.keys)
    }

    // Invalidate all the observations.
    //
    deinit {
        observations.forEach { observation in
            observation.invalidate()
        }
    }
    
    // Observe a file transfer, and hold the observation.
    //
    func observe(_ fileTransfer: WCSessionFileTransfer, handler: ((Progress) -> Void)? = nil) {
        progresssDescriptions[fileTransfer] = fileTransfer.progress.localizedDescription
        let observation = fileTransfer.progress.observe(\.fractionCompleted) { progress, _ in
            self.progresssDescriptions[fileTransfer] = progress.localizedDescription
            handler?(progress)
        }
        if let existingObservation = fileTransferObervations[fileTransfer] {
            existingObservation.invalidate()
        }
        fileTransferObervations[fileTransfer] = observation
    }
    
    // Un-observe a file transfer, and invalidate the observation.
    //
    func unobserve(_ fileTransfer: WCSessionFileTransfer) {
        if let observation = fileTransferObervations[fileTransfer] {
            observation.invalidate()
            fileTransferObervations[fileTransfer] = nil
        }
        progresssDescriptions[fileTransfer] = nil
    }
    
    func observe(_ fileTransfers: [WCSessionFileTransfer]) {
        for fileTransfer in fileTransfers {
            observe(fileTransfer)
        }
    }

    func reset() {
        observations.forEach { observation in
            observation.invalidate()
        }
        fileTransferObervations = [:]
        progresssDescriptions = [:]
    }
}
