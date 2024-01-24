/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The complication controller class for the complication.
*/

import ClockKit

// The complication supports the Modular Large family and shows a random number for the current timeline entry.
// Activate the complication by following these steps:
// 1. Choose a Modular watch face on the watch.
// 2. Press the watch face to show the customization screen, tap the Edit button, then swipe right to show the configuration screen.
// 3. Tap the tall body area, then rotate the digital crown to find the SimpleWatchConnectivity complication.
// 4. Press the digital crown and tap the screen to go back to finish the configuration.
//
class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // In watchOS 7 and later, use getComplicationDescriptors(handler:) to define the supported complication families.
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptor = CLKComplicationDescriptor(identifier: "SimpleWC", displayName: "SimpleWC", supportedFamilies: [.modularLarge])
        handler([descriptor])
    }
    
    // MARK: - Timeline Configuration.
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication,
                                          withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.forward, .backward])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population.
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Only support .modularLarge.
        guard complication.family == .modularLarge else { handler(nil); return }
        
        // Display a random number string on the body.
        let tallBody = CLKComplicationTemplateModularLargeTallBody(headerTextProvider: CLKSimpleTextProvider(text: "SimpleWC"),
                                                                   bodyTextProvider: CLKSimpleTextProvider(text: "\(Int.random(in: 0..<400))"))
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: tallBody)
        
        // Pass the entry to ClockKit.
        handler(entry)
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int,
                            withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date.
        handler(nil)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int,
                            withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date.
        handler(nil)
    }
    
    // MARK: - Placeholder Templates.
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // ClockKit calls this method once per supported complication and caches the results.
        handler(nil)
    }
    
    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // Only support .modularLarge.
        guard complication.family == .modularLarge else { handler(nil); return }
        
        // Display a random number string on the body.
        let tallBody = CLKComplicationTemplateModularLargeTallBody(headerTextProvider: CLKSimpleTextProvider(text: "SimpleWC"),
                                                                   bodyTextProvider: CLKSimpleTextProvider(text: "Random"))
        // Pass the template to ClockKit.
        handler(tallBody)
    }
}
