//
//  File.swift
//  OBDIQPakage
//
//  Created by Arvind Mehta on 21/02/25.
//

import Foundation


public class VehicleEntries {

    public var VIN: String = ""
    public let attributedDescription: String = ""
    public var dateAdded: Date = Date()
    public var description: String = ""
    public let descriptionWithEngine: String = ""
    public var engine: String = ""
    public let engineString: String = ""
    public var id: String = ""
    public let isEmptyOfData: Bool = false
    public var lastScanDate: Date? = nil
    public var make: String = ""
    public var makeID: Int? = nil
    public var manualData: Bool = false
    public var manualVIN: Bool = false
    public var model: String = ""
    public var modelID: Int? = nil
    public var shortDescription: String = ""
    public var vehiclePowertrainType: String? = nil
    public var withDevice: Bool = false
    public var year: Int = 0
    public let yearString: String = ""

    public init() {}
}

