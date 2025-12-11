//
//  File.swift
//  OBDIQPakage
//
//  Created by Arvind Mehta on 21/02/25.
//

import Foundation
import SwiftyJSON


public struct DTCResponse: Sendable {
    public var dtcErrorCode: String = ""
    public var desc: String = ""
    public var status: String = ""
    public var name: String = ""
    public var section: String = ""
}


public class DTCResponseModel: @unchecked Sendable {
    public var id: String? = nil
    public var moduleName: String = ""
    public var responseStatus: String? = nil
    public var identifier: String = ""
    public var dtcCodeArray: [DTCResponse] = []

    func removeDuplicateDTCResponses() {
        var unique = Set<String>()
        var filtered: [DTCResponse] = []

        for item in dtcCodeArray {
            if unique.insert(item.dtcErrorCode).inserted {
                filtered.append(item)
            }
        }
        dtcCodeArray = filtered
    }
}


public class RecallResponse: @unchecked Sendable {
    public var vin: String?
    public var year: String?
    public var makeName: String?
    public var modelName: String?
    public var styleName: String?
    public var sourceIdentifier: String?
    public var storeIdentifier: String?
    public var vehicleNotes: String?
    public var results: [RecallResult] = []
    
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

public class RecallResult: @unchecked Sendable {
    // 🔹 Common / Old API fields
    public var manufacturer: String?
    public var campaignNumber: String?
    public var actionNumber: String?
    public var reportReceivedDate: String?
    public var component: String?
    public var summary: String?
    public var consequence: String?
    public var remedy: String?
    public var notes: String?
    public var modelYear: String?
    public var make: String?
    public var model: String?
    
    // 🔹 New API fields
    public var status: String?
    public var noRemedy: Bool = false
    public var recallTypeCode: String?
    public var nhtsaCampaignNumber: String?
    public var mfgCampaignNumber: String?
    public var bulletinNumber: String?
    public var componentDescriptionrecall: String?
    public var subject: String?
    public var emissionsRelated: Bool = false
    public var mfgName: String?
    public var mfgText: String?
    public var defectSummary: String?
    public var consequenceSummary: String?
    public var correctiveSummary: String?
    public var recallNotes: String?
    public var fmvss: String?
    public var stopSale: String?
    public var nhtsaRecallDate: String?
    public var vehicleRecallUuid: String?
    
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

public class Configuration: @unchecked Sendable {
    public var autoAppUrl :String?
    public var nhtsaUrl:String?
    public var recallToken :String?
   
    public var scan :String?
    public var repairCost :String?
    public var repairInfo :String?
    public var recallApi :String?
    public var repairClubToken :String?
    
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
public struct VariableData: Sendable {
    public let id: Int?
    public let isDeleted: Int?
    public let recallToken: String?
    public let repairClubToken: String?
    public let autoAppUrl: String?
    public let scan: String?
    public let nhtsaUrl: String?
    public let repairCost: String?
    public let recallApi: String?
    public let repairInfo: String?
    public let createdAt: String?
    public let updatedAt: String?

    init(json: JSON) {
        self.id = json["data"]["id"].intValue
        self.isDeleted = json["data"]["is_deleted"].intValue
        self.recallToken = json["data"]["recallToken"].stringValue
        self.repairClubToken = json["data"]["repairClubToken"].stringValue
        self.autoAppUrl = json["data"]["autoAppUrl"].stringValue
        self.scan = json["data"]["scan"].stringValue
        self.nhtsaUrl = json["data"]["nhtsaUrl"].stringValue
        self.repairCost = json["data"]["repairCost"].stringValue
        self.recallApi = json["data"]["recallApi"].stringValue
        self.repairInfo = json["data"]["repairInfo"].stringValue
        self.createdAt = json["data"]["createdAt"].stringValue
        self.updatedAt = json["data"]["updatedAt"].stringValue
    }
}

