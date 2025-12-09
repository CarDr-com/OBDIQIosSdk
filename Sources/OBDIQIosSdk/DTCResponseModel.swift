//
//  File.swift
//  OBDIQPakage
//
//  Created by Arvind Mehta on 21/02/25.
//

import Foundation
import SwiftyJSON


struct DTCResponse {
    var dtcErrorCode: String = ""
    var desc: String = ""
    var status: String = ""
    var name: String = ""
    var section: String = ""
}

public class DTCResponseModel {
    var id: String? = nil
    var moduleName: String = ""
    var responseStatus: String? = nil
    var identifier: String = ""
    var dtcCodeArray: [DTCResponse] = []

    // Function to remove duplicate DTCResponses based on dtcErrorCode
    func removeDuplicateDTCResponses() {
        var uniqueDTCErrorCodes = Set<String>()
        var uniqueDTCResponses: [DTCResponse] = []

        for dtcResponse in dtcCodeArray {
            if uniqueDTCErrorCodes.insert(dtcResponse.dtcErrorCode).inserted {
                uniqueDTCResponses.append(dtcResponse)
            }
        }

        dtcCodeArray = uniqueDTCResponses
    }
}

class RecallResponse {
    var vin: String?
    var year: String?
    var makeName: String?
    var modelName: String?
    var styleName: String?
    var sourceIdentifier: String?
    var storeIdentifier: String?
    var vehicleNotes: String?
    var results: [RecallResult] = []
    
    init(json: JSON) {
        if json["openRecalls"].exists() {
            // New API
            vin              = json["vin"].string
            year             = json["year"].string
            makeName         = json["makeName"].string
            modelName        = json["modelName"].string
            styleName        = json["styleName"].string
            sourceIdentifier = json["sourceIdentifier"].string
            storeIdentifier  = json["storeIdentifier"].string
            vehicleNotes     = json["vehicleNotes"].string
            results          = json["openRecalls"].arrayValue.map { RecallResult.from(json: $0) }
        } else {
            // Old API
            results          = json["results"].arrayValue.map { RecallResult.from(json: $0) }
        }
    }
    
    func safetyRecalls() -> [RecallResult] {
        return results.filter { $0.isSafetyRecall() }
    }
    
    func stopSaleRecalls() -> [RecallResult] {
        return results.filter { $0.isStopSale() }
    }
}

class RecallResult {
    // 🔹 Common / Old API fields
    var manufacturer: String?
    var campaignNumber: String?
    var actionNumber: String?
    var reportReceivedDate: String?
    var component: String?
    var summary: String?
    var consequence: String?
    var remedy: String?
    var notes: String?
    var modelYear: String?
    var make: String?
    var model: String?
    
    // 🔹 New API fields
    var status: String?
    var noRemedy: Bool = false
    var recallTypeCode: String?
    var nhtsaCampaignNumber: String?
    var mfgCampaignNumber: String?
    var bulletinNumber: String?
    var componentDescriptionrecall: String?
    var subject: String?
    var emissionsRelated: Bool = false
    var mfgName: String?
    var mfgText: String?
    var defectSummary: String?
    var consequenceSummary: String?
    var correctiveSummary: String?
    var recallNotes: String?
    var fmvss: String?
    var stopSale: String?
    var nhtsaRecallDate: String?
    var vehicleRecallUuid: String?
    
    // MARK: - Initializers
    
    /// Old API mapping
    init(oldJson: JSON) {
        manufacturer       = oldJson["Manufacturer"].string
        campaignNumber     = oldJson["NHTSACampaignNumber"].string
        actionNumber       = oldJson["NHTSAActionNumber"].string
        reportReceivedDate = oldJson["ReportReceivedDate"].string
        component          = oldJson["Component"].string
        summary            = oldJson["Summary"].string
        consequence        = oldJson["Consequence"].string
        remedy             = oldJson["Remedy"].string
        notes              = oldJson["Notes"].string
        modelYear          = oldJson["ModelYear"].string
        make               = oldJson["Make"].string
        model              = oldJson["Model"].string
    }
    
    /// New API mapping
    init(newJson: JSON) {
        status                   = newJson["status"].string
        noRemedy                 = newJson["noRemedy"].boolValue
        recallTypeCode           = newJson["recallTypeCode"].string
        nhtsaCampaignNumber      = newJson["nhtsaCampaignNumber"].string
        mfgCampaignNumber        = newJson["mfgCampaignNumber"].string
        bulletinNumber           = newJson["bulletinNumber"].string
        componentDescriptionrecall = newJson["componentDescription"].string
        subject                  = newJson["subject"].string
        emissionsRelated         = newJson["emissionsRelated"].boolValue
        mfgName                  = newJson["mfgName"].string
        mfgText                  = newJson["mfgText"].string
        defectSummary            = newJson["defectSummary"].string
        consequenceSummary       = newJson["consequenceSummary"].string
        correctiveSummary        = newJson["correctiveSummary"].string
        recallNotes              = newJson["recallNotes"].string
        fmvss                    = newJson["fmvss"].string
        stopSale                 = newJson["stopSale"].string
        nhtsaRecallDate          = newJson["nhtsaRecallDate"].string
        vehicleRecallUuid        = newJson["vehicleRecallUuid"].string
    }
    
    // MARK: - Factory
    static func from(json: JSON) -> RecallResult {
        if json["nhtsaCampaignNumber"].exists() {
            return RecallResult(newJson: json)
        } else {
            return RecallResult(oldJson: json)
        }
    }
    
    // MARK: - Utility
    func isStopSale() -> Bool {
        return stopSale?.uppercased() == "YES"
    }
    
    func isSafetyRecall() -> Bool {
        return recallTypeCode?.uppercased() == "V"
    }
    
    /// Convert date string (old or new API) into `Date`
    func recallDate() -> Date? {
        let formatter = DateFormatter()
        
        // Try new API format first
        if let dateString = nhtsaRecallDate {
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateString)
        }
        
        // Fallback: old API format
        if let dateString = reportReceivedDate {
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.date(from: dateString)
        }
        
        return nil
    }
}

class Configuration {
    var autoAppUrl :String?
    var nhtsaUrl:String?
    var recallToken :String?
   
    var scan :String?
    var repairCost :String?
    var repairInfo :String?
    var recallApi :String?
    var repairClubToken :String?
    
    init(json:JSON){
        self.autoAppUrl = json["auto_app_url"].stringValue
        self.nhtsaUrl = json["nhtsa_url"].stringValue
        self.recallToken = json["recallToken"].stringValue
        self.scan = json["scan"].stringValue
        self.repairCost = json["repairCost"].stringValue
        self.repairInfo = json["repairInfo"].stringValue
        self.recallApi = json["recallApi"].stringValue
        self.repairClubToken = json["repairClubToken"].stringValue
    }
}
