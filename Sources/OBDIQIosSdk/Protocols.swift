//
//  File.swift
//  OBDIQPakage
//
//  Created by Arvind Mehta on 21/02/25.
//

import Foundation
import RepairClubSDK
public protocol ConnectionListener {
     func didDevicesFetch(foundedDevices: [DeviceItem]?)
    func didCheckScanStatus(status: String)
    func didFetchVehicleInfo(vehicleEntry: VehicleEntries)
    func didFetchMil(mil: Bool)
    func isReadyForScan(status: Bool, isGeneric: Bool)
    func didUpdateProgress(progressStatus: String, percent: String)
    func didReceivedCode(model: [DTCResponseModel]?)
    func didReceivedRepairCost(jsonString: String)
    func didScanForDevice(startScan: Bool)
}
