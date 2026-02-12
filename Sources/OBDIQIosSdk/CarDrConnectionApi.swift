
//
//  CarDrConnectionApi.swift
//  test
//
//  Created by Arvind Mehta on 07/04/23.
//  Updated for Swift 6 concurrency compatibility (actor-backed non-Sendable state).
//

import Foundation
import RepairClubSDK
import CoreBluetooth
import SwiftyJSON



@available(iOS 13.0.0, *)
public class CarDrConnectionApi: @unchecked Sendable {

    public init() { }

    // MARK: - Stored properties
    var dtcErrorCodeArray = [DTCResponseModel]()
    private let rc = RepairClubManager.shared
    private var connectionListner: ConnectionListener? = nil
    private var connectionEntry: ConnectionEntry? = nil

    var yearstr = ""
    var make = ""
    var model = ""
    var carName = ""
    var fuelType = ""
    var isConnected = false
    var currentFirmwareVersion = ""
    private var emissionList = [EmissionRediness]()
    private var isReadinessComplete = false
    private var passFail = ""
    private var controller = [ModuleItem]()
    private var warmUpCyclesSinceCodesCleared: Double = 0.0
    private var warmUpCyclesSinceCodesClearedStr = "-"
    private var distanceSinceCodesCleared: Int = 0
    private var distanceSinceCodesClearedStr = "-"
    private var timeSinceTroubleCodesCleared: Int = 0
    private var timeSinceTroubleCodesClearedStr = "-"
    private var timeRunWithMILOn: Int = 0
    private var timeRunWithMILOnStr = "-"
    private var variableData: VariableData? = nil
    private var recallResponse: RecallResponse? = nil
    var scanID = ""
    var isMilOn = false
    var dictonary = [String: Any]()
    var connectionStates: [ConnectionStage: ConnectionState] = [:]
    var isAutoRecall = false

    public var connectionHandler: ((ConnectionEntry, ConnectionStage, ConnectionState?) -> Void)? = nil

    var vinNumber = ""
    var hardwareIdentifier = ""
    var isProductionReady = false


    
    // MARK: - Initial Function to Initialize the SDK
    public func initialize(partnerID: String,
                           isProductionReady: Bool = false,
                           listener: ConnectionListener) {

        self.connectionListner = listener
        self.isProductionReady = isProductionReady

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        getVariable(partnerID: partnerID) { [weak self] it in
            guard let self = self else { return }

     
            guard let it = it else {
                return
            }

      
            self.variableData = it

        
            self.rc.configureSDK(
                tokenString: it.repairClubToken ?? "",
                appName: "OBDIQ ULTRA SDK iOS",
                appVersion: appVersion,
                userID: "support@cardr.com"
            )

        
            self.dissconnectOBD()
            self.connectionListner?.didScanForDevice(startScan: true)
        }
    }


    // MARK: - Helpers for building requests
    private func makeJSONRequest(urlString: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(self.variableData?.accessToken ?? "", forHTTPHeaderField: "access-token")
        req.addValue(self.variableData?.serverKey ?? "", forHTTPHeaderField: "server-key")
        req.httpBody = body
        return req
    }

    // MARK: - getVariable
    private func getVariable(partnerID: String,
                             completion: @Sendable @escaping (VariableData?) -> Void) {

        guard let url = URL(string: Constants.GET_VARIABLE_URL) else {
            print("Invalid URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(partnerID, forHTTPHeaderField: "partner-id") // ✅ Android same header

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                print("API Error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            do {
                let jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let json = JSON(jsonObj ?? [:])

                // ✅ Now model handles parsing internally
                let variableData = VariableData(json: json)

                DispatchQueue.main.async {
                    self.variableData = variableData
                    completion(variableData)
                }

            } catch {
                print("JSON decode error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }

        task.resume()
    }


    // MARK: - getConfigValues
    private func getConfigValues(completion: @Sendable @escaping (Configuration) -> Void) {
        guard let url = URL(string: "") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(self.variableData?.accessToken ?? "", forHTTPHeaderField: "access-token")
        request.addValue(self.variableData?.serverKey ?? "", forHTTPHeaderField: "server-key")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("Recall API error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data returned")
                return
            }

            do {
                if let jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let jsonValue = JSON(jsonObj)
                    let response = Configuration(json: jsonValue)
                    DispatchQueue.main.async {
                        completion(response)
                    }
                }
            } catch {
                print("JSON Parse Error: \(error.localizedDescription)")
            }
        }

        task.resume()
    }

    // MARK: - Disconnect
    public func dissconnectOBD() {
        self.rc.stopTroubleCodeScan()
        self.rc.disconnectFromDevice()
        self.rc.advancedValueStopStreaming()
        self.dtcErrorCodeArray.removeAll()
        self.scanID = ""
        self.isConnected = false
        self.isMilOn = false
        self.emissionList.removeAll()
        self.clearCodesReset()
        self.controller.removeAll()
    }

    // MARK: - scanForDevice
    public func scanForDevice() {
        rc.setSampleVehicleOnSim(.chevroletCamaro2010)
        rc.returnDevices { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let devices):
                self.connectionListner?.didDevicesFetch(foundedDevices: devices)
                if let nearestDevice = devices.sorted(by: { $0.rssi > $1.rssi }).first {
                    self.connectPeripheral(peripheral: nearestDevice.device)
                }
            case .failure(_):
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - connectPeripheral
    func connectPeripheral(peripheral: CBPeripheral?) {
        if peripheral == nil {
            return
        }
        connectionStates.removeAll()
        self.rc.connectToDevice(peripheral: peripheral!) { [weak self] connectionEntry, connectionstage, connectionState in
            guard let self = self else { return }

            self.connectionStates[connectionstage] = connectionState
            self.connectionEntry = connectionEntry
            self.connectionHandler?(connectionEntry, connectionstage, connectionState)
            self.connectionListner?.didCheckScanStatus(status: "\(connectionstage)")
            switch connectionstage {
            case .deviceHandshake:
                print("Connection: deviceHandshake - \(connectionState)")
                switch connectionState {
                case .completed:
                    if let device = connectionEntry.deviceItem {
                        self.hardwareIdentifier = device.hardwareIdentifier ?? device.deviceIdentifier
                    }
                default: break
                }

            case .mainBusFound:
                print("Connection: mainBusFound - \(connectionState)")
            case .vinReceived:
                switch connectionState {
                case .completed:
                    if let vin = connectionEntry.vin {
                        self.vinNumber = vin
                    }
                case .failed(_):
                    if let vin = connectionEntry.vin {
                        if vin.isEmpty {
                            // no-op
                        }
                    }
                default: break
                }
            case .vehicleDecoded:
                if let vehicleEntry = connectionEntry.vehicleEntry {
                    self.carName = vehicleEntry.shortDescription
                    self.yearstr = vehicleEntry.yearString
                    self.make = vehicleEntry.make
                    self.model = vehicleEntry.model
                    self.vinNumber = vehicleEntry.VIN

                    let entry = VehicleEntries()
                    entry.VIN = vehicleEntry.VIN
                    entry.shortDescription = vehicleEntry.shortDescription
                    entry.make = vehicleEntry.make
                    entry.model = vehicleEntry.model
                    entry.description = vehicleEntry.description
                    entry.engine = vehicleEntry.engine
                    entry.vehiclePowertrainType = vehicleEntry.vehiclePowertrainType?.rawValue ?? "Unknown"
                    self.getDeviceFirmwareVersion()
                    self.connectionListner?.didFetchVehicleInfo(vehicleEntry: entry)
                } else if let vin = connectionEntry.vin {
                    _ = vin
                }
            case .configDownloaded:
                self.isConnected = true
                switch connectionState {
                case .completed:
                    print("Complete")
                case .failed(_):
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
                case .manuallyEntered, .started, .notStarted:
                    break
                @unknown default:
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
                }
            case .busSyncedToConfig:
                switch connectionState {
                case .completed:
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: false)
                case .failed(_):
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
                case .manuallyEntered, .started, .notStarted:
                    break
                @unknown default:
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
                }
            case .milChecking:
                if !self.isMilOn {
                    if connectionState == .completed, let milStatus = connectionEntry.milOn {
                        self.isMilOn = milStatus
                    }
                }
                self.connectionListner?.didFetchMil(mil: self.isMilOn)
            case .readinessMonitors:
                print("Connection: readinessMonitors - \(connectionState)")
            case .supportedPIDsReceived:
                print("Connection: supportedPIDsReceived - \(connectionState)")
            case .supportedMIDsReceived:
                print("Connection: supportedMIDsReceived - \(connectionState)")
            case .odometerReceived:
                print("Connection: ODOMETER - \(String(describing: connectionEntry.odometer))")
            @unknown default: break
            }
        }
    }

    // MARK: - startScan / startAdvanceScan
    public func startScan() {
        scanID = ""

        if let state = connectionStates[.configDownloaded], case .failed = state {
            startAdvanceScan(advancescan: false)
            return
        }

        if connectionStates[.busSyncedToConfig] == .completed {
            startAdvanceScan()
        } else if let state = connectionStates[.busSyncedToConfig], case .failed = state {
            startAdvanceScan(advancescan: false)
        }
    }

    var fail = 0
    func startAdvanceScan(advancescan: Bool = true) {
        var strArr = [String]()
        rc.startTroubleCodeScan(advancedScan: advancescan) { [weak self] progressupdate in
            guard let self = self else { return }
            switch progressupdate {
                case .scanStarted:
                    break
                case .progressUpdate(let progress):
                    var per = ceil(progress * 100) / 100
                    let percent = String(format: "%.2f", per * 100)
                    self.connectionListner?.didUpdateProgress(progressStatus: "progressupdate", percent: percent)
                case .moduleScanningUpdate(moduleName: let moduleName):
                    print("ModuleName ======= \(moduleName)")
                case .modulesUpdate(modules: let modulesUpdate):
                    print("")
                case .scanSucceeded(modules: let modulesUpdate, scanEntry: let scanEntry, errors: let errors):
                    var modules = modulesUpdate.sorted(by: {
                        if $0.name.contains("Generic Codes") { return true }
                        if $1.name.contains("Generic Codes") { return false }

                        let responseOrder: [ResponseStatus: Int] = [
                            .responded: 1,
                            .awaitingDecode: 2,
                            .didNotRespond: 3,
                            .unknown: 4
                        ]

                        let order0 = responseOrder[$0.responseStatus] ?? Int.max
                        let order1 = responseOrder[$1.responseStatus] ?? Int.max

                        if order0 != order1 {
                            return order0 < order1
                        }

                        if !$0.codes.isEmpty && $1.codes.isEmpty { return true }
                        if $0.codes.isEmpty && !$1.codes.isEmpty { return false }

                        return $0.name < $1.name
                    })

                    let distinctModules = Array(Set(modules.map { $0.name })).compactMap { name in
                        modules.first { $0.name == name }
                    }
                    controller.append(contentsOf: distinctModules)
                    let codesCount = modules.reduce(0) { $0 + $1.codes.count }

                    var dtcErrorCodeList = [DTCResponseModel]()
                    for module in distinctModules {
                        let moduleName = module.name
                        var dtcResponse = DTCResponseModel()
                        dtcResponse.id = module.id.uuidString
                        dtcResponse.moduleName = module.name
                        dtcResponse.responseStatus = module.responseStatus.description
                        dtcResponse.identifier = module.identifier

                        let codesList = module.codes
                            .distinctBy { $0.code }
                            .map { code in
                                var dtc = DTCResponse()
                                dtc.dtcErrorCode = code.code
                                dtc.status = code.statusesDescription
                                dtc.desc = code.description ?? ""
                                dtc.name = moduleName
                                return dtc
                            }

                        dtcResponse.dtcCodeArray = Array(codesList)
                        dtcErrorCodeList.append(dtcResponse)
                    }
                    self.dtcErrorCodeArray.removeAll()
                    let distinctArray = dtcErrorCodeList.distinctBy { $0.moduleName }
                    distinctArray.forEach { model in
                        model.removeDuplicateDTCResponses()
                    }
                    self.dtcErrorCodeArray.append(contentsOf: distinctArray)

                    self.connectionListner?.didReceivedCode(model: self.dtcErrorCodeArray)
                    self.callScanApi()

                case .scanFailed(errors: let errors):
                    break
                @unknown default:
                    break
                }
        }
    }
    
    @MainActor
    public  func stopTroubleCodeScan() {
        self.rc.stopTroubleCodeScan()
     }

    // MARK: - clearCode (uses concurrency)
    @MainActor
    func clearCode(completion: @Sendable @escaping (OperationProgressUpdate) -> Void) {
        Task { [weak self] in
            guard let self = self else { return }

            if !self.isConnected {
                // Return devices
                self.rc.returnDevices { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                        case .success(let devices):
                            guard let nearestDevice = devices.sorted(by: { $0.rssi > $1.rssi }).first,
                                  let device = nearestDevice.device else { return }
                            self.rc.connectToDevice(peripheral: device) { [weak self] connectionEntry, connectionStage, connectionState in
                                guard let self = self else { return }
                                self.isConnected = true

                                if connectionStage == .vinReceived {
                                    switch connectionState {
                                        case .completed, .failed(_):
                                            Task { [weak self] in
                                                guard let self = self else { return }
                                                try await Task.sleep(nanoseconds: 1_000_000_000)
                                                self.rc.clearAllCodes { progress in
                                                    Task { @MainActor in
                                                        completion(progress)
                                                    }
                                                }
                                            }
                                        default: break
                                    }
                                }
                            }
                        case .failure(let error):
                            print("Error: \(error)")
                        @unknown default:
                            print("Unknown error")
                    }
                }
            } else {
                // Already connected → clear codes directly
                Task {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                   
                        self.rc.clearAllCodes { progress in
                            Task { @MainActor in
                                completion(progress)
                            }
                        }
                    
                }
            }
        }
    }

    // MARK: - processDtcCodes (actor-backed)
    func processDtcCodes(
        vinNumber: String,
        dtcErrorCodeArray: [DTCResponseModel]
    ) {
        var dtcArr = [[String: String]]()

        for model in self.dtcErrorCodeArray {
            let module = model.moduleName
            for dtc in model.dtcCodeArray {
                let status = dtc.status.lowercased()
                if status.contains("active")
                    || status.contains("confirmed")
                    || status.contains("permanent") {

                    let cleaned = dtc.desc
                        .replacingOccurrences(of: "[^a-zA-Z0-9 .,]", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

                    dtcArr.append([
                        "code": dtc.dtcErrorCode,
                        "module": module,
                        "code_desc": cleaned
                    ])
                }
            }
        }

        guard !scanID.isEmpty else {
            connectionListner?.didReceiveRepairCost(result: nil)
            return
        }

        let chunkSize = 5
        let dtcArrChunks = stride(from: 0, to: dtcArr.count, by: chunkSize)
            .map { Array(dtcArr[$0..<min($0 + chunkSize, dtcArr.count)]) }

        let dispatchGroup = DispatchGroup()
        let syncQueue = DispatchQueue(label: "repair.cost.sync.queue")

        // 🆕 Replacement for mutated captured vars
        let state = DtcProcessingState()

        guard let repairInfo = variableData?.repairInfo else { return }

        for chunk in dtcArrChunks {
            dispatchGroup.enter()

            let params: [String: Any] = [
                "dtcCode": chunk,
                "vin": vinNumber
            ]

            callApiJSON(url: Constants.BASE_URL + repairInfo, params: params) { responseDict in
                syncQueue.async {
                    if let dict = responseDict {
                        state.jsonResponses.append(dict.value)
                        state.successful += 1
                    } else {
                        state.failed += 1
                    }
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }

            syncQueue.async {
                let responsesCopy = state.jsonResponses
                let failedCopy = state.failed

                DispatchQueue.main.async {
                    let mergedDict = responsesCopy.reduce(into: [String: Any]()) { result, dict in
                        result.merge(dict) { _, new in new }
                    }

                    if failedCopy == dtcArrChunks.count {
                        self.connectionListner?.didReceiveRepairCost(result: nil)
                        return
                    }

                    self.postRepairCost(dtcErrorCodeArray: dtcErrorCodeArray, jsonObject: mergedDict)
                    self.connectionListner?.didReceiveRepairCost(result: mergedDict)
                }
            }
        }
    }



    // MARK: - callApiJSON (keeps @Sendable callback; safe due to actor usage)
    private func callApiJSON(
        url: String,
        params: [String: Any],
        callback: @escaping @Sendable (SendableDict?) -> Void
    ) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params) else {
            callback(nil)
            return
        }

        guard let request = makeJSONRequest(urlString: url, method: "POST", body: jsonData) else {
            callback(nil)
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if error != nil {
                callback(nil)
                return
            }

            guard let data = data else {
                callback(nil)
                return
            }

            if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                callback(SendableDict(value: jsonResponse))
            } else {
                callback(nil)
            }
        }.resume()
    }



    // MARK: - callScanApi
    private func callScanApi() {

        guard !vinNumber.isEmpty else {
            print("callScanApi: VIN number is empty")
            return
        }

        // ------- Build DTC array -------
        let dtcArr: [[String: Any]] = dtcErrorCodeArray.flatMap { model -> [[String: Any]] in
            model.dtcCodeArray.map { dtc in
                let (category, _, subCategory) = separateArrays(response: dtc, moduleName: model.moduleName)
                return [
                    "dtc_status": dtc.status,
                    "dtc_code": dtc.dtcErrorCode,
                    "dtc_desc": dtc.desc,
                    "modulename": model.moduleName,
                    "category_name": category,
                    "sub_category_name": subCategory,
                    "category_id": 1,
                    "sub_category_id": 1
                ]
            }
        }

        // Count generic and OEM codes
        let (genericCount, oemCount) = dtcErrorCodeArray.reduce(into: (0, 0)) { counts, model in
            let isGeneric = model.moduleName.localizedCaseInsensitiveContains("generic")
                || model.moduleName.localizedCaseInsensitiveContains("standard")

            if isGeneric {
                counts.0 += model.dtcCodeArray.count
            } else {
                counts.1 += model.dtcCodeArray.count
            }
        }

        // Filter modules (responded only, non-generic)
        let controllerArr = filterModules(filterNonGenericModules(controller)).map { $0.name }
        let uniqueControllerArr = Array(
            Set(
                dtcErrorCodeArray
                    .filter { $0.responseStatus == ResponseStatus.responded.rawValue }
                    .compactMap { $0.moduleName }   // safer than map if optional
                    .filter { !$0.localizedCaseInsensitiveContains("generic")
                           && !$0.localizedCaseInsensitiveContains("standard") }
            )
        )

        guard let scanPath = variableData?.scan else {
            print("❌ Missing scan API URL path")
            return
        }

        let urlString = Constants.BASE_URL + scanPath
        guard let url = URL(string: urlString) else {
            print("Invalid URL for scan API")
            return
        }

        // ------- Build parameters -------
        let parameters: [String: Any] = [
            "modules": uniqueControllerArr,
            "vin_number": vinNumber,
            "count_generic": genericCount,
            "odometer": "",
            "milcheck": isMilOn,
            "scan_date": getCurrentDateFormatted(),
            "version_firmware": currentFirmwareVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "count_oem": oemCount,
            "year": yearstr,
            "make": make,
            "model": model,
            "device_type": "SDK iOS",
            "serial_number": hardwareIdentifier,
            "dtc_codes": dtcArr
        ]

        // Encode JSON
        guard let body = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            print("callScanApi: JSON encoding failed")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(self.variableData?.accessToken ?? "", forHTTPHeaderField: "access-token")
        request.addValue(self.variableData?.serverKey ?? "", forHTTPHeaderField: "server-key")

        // ------- Perform request (no Sendable issues) -------
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("callScanApi: API error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("callScanApi: No data returned")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any] {

                    var idString = ""

                    if let id = dataObj["id"] as? Int {
                        idString = "\(id)"
                    } else if let id = dataObj["id"] as? String {
                        idString = id
                    }

                    self.scanID = idString
                    print("callScanApi: Scan ID = \(idString)")

                    DispatchQueue.main.async {
                        self.connectionListner?.didReadyForRepairInfo(isReady: true)
                    }
                }

            } catch {
                print("callScanApi: JSON parse error: \(error.localizedDescription)")
            }
        }
        .resume()
    }
    
    // MARK: - Helper utilities used across the class

    /// Returns (category, subCategoryMain, subCategory) for a DTC response + module name.
    /// subCategoryMain is kept for compatibility with existing callers (unused in many places).
    func separateArrays(response: DTCResponse, moduleName: String) -> (String, String, String) {
        // Normalize module name for category lookup
        let cat = getResponseFromJSON(msg: moduleName.lowercased())

        // Determine severity/attention based on status text
        let status = response.status.lowercased()
        let attentionStatuses = ["active", "current", "permanent", "warning light"]

        if attentionStatuses.contains(where: { status.contains($0) }) || status.contains("confirmed") {
            // Attention-level DTC
            return ("Attention", "", cat)
        } else {
            // Informational DTC
            return ("INFORMATIONAL", "INFORMATIONAL", cat)
        }
    }

    /// Map of module names (lowercased / canonicalized) → category string.
    /// Extend this map with your real categories as needed.
    private let sampleMap: [String: String] = [
        "modgenericule": "Performance & Compliance",
        "generic codes": "Other & Non Categorized",
        "electric power steering": "Safety & Operability",
        "drive door motor": "Comfort & Convenience",
        "evaporative system": "Emissions",
        "egr/vvt system": "Emissions",
        "nmhc catalyst": "Emissions"
    ]

    /// Safe lookup that falls back to "Other & Non Categorized"
    func getResponseFromJSON(msg: String) -> String {
        // msg is expected to be lowercased by caller where appropriate
        return sampleMap[msg.lowercased()] ?? "Other & Non Categorized"
    }

    /// Return current date string used for API payloads: "MM-dd-yyyy h:mm a"
    func getCurrentDateFormatted() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy h:mm a"
        dateFormatter.locale = Locale.current
        return dateFormatter.string(from: Date())
    }

    /// Filters out modules whose name contains "generic" or exactly "Standard Codes"
    private func filterNonGenericModules(_ modules: [ModuleItem]) -> [ModuleItem] {
        return modules.filter {
            let lower = $0.name.lowercased()
            return !lower.contains("generic") && $0.name != "Standard Codes"
        }
    }

    /// Keeps only modules that responded (responseStatus == .responded)
    private func filterModules(_ modules: [ModuleItem]) -> [ModuleItem] {
        return modules.filter {
            $0.responseStatus == .responded
        }
    }


    // MARK: - postRepairCost
    private func postRepairCost(dtcErrorCodeArray: [DTCResponseModel], jsonObject: [String: Any]?) {
        guard !scanID.isEmpty, !dtcErrorCodeArray.isEmpty else { return }
        let response = makeJsonOfResponse(jsonObject: jsonObject)
        guard let repaircost = variableData?.repairCost else {
            print("❌ Missing API URL components")
            return
        }
        callApiJSON(url: Constants.BASE_URL + repaircost, params: response) { response in
            print("Repair Cost API Response: \(String(describing: response))")
        }
    }

    private func makeJsonOfResponse(jsonObject: [String: Any]?) -> [String: Any] {
        return [
            "scan_id": scanID,
            "repaircost": jsonObject ?? [:]
        ]
    }

    // MARK: - updateFirm / stopFirmware
    public func updateFirm(completion: @Sendable @escaping (String) -> Void) {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] timer in
            guard let self = self else { return }
            var result = self.rc.getNewestAvailableFirmwareVersion()
            var currnt = ""
            do {
                currnt = try result.get() ?? ""
            } catch {
                // ignore
            }

            self.rc.startDeviceFirmwareUpdate(to: currnt, reqReleaseLevel: .production) { [weak self] versionInDouble in
                guard let _ = self else { return }
                completion("\(versionInDouble)")
            } completionCallback: { [weak self] error in
                guard let _ = self else { return }
                completion("Error")
            }
        }
    }

    func stopFirmware() {
        self.rc.stopDeviceFirmwareUpdate()
    }

    // MARK: - Emissions and other helpers (left mostly unchanged)
    public func getEmissionMonitors(callback: @Sendable @escaping (_ emissions: [EmissionRediness]) -> Void) {
        isReadinessComplete = false
        emissionList.removeAll()

        rc.subscribeToMonitors { [weak self] str in
            guard let self = self else { return }
            do {
                self.emissionList.removeAll()
                let data = try str.get()
                data.forEach { monitor in
                    if monitor.readinessStatus?.first != nil {
                        if monitor.readinessStatus!.first! {
                            self.emissionList.append(EmissionRediness(name: monitor.valueName, available: monitor.readinessStatus?.first ?? false, status: monitor.readinessStatus?.last ?? false, desc: monitor.description))
                        }
                    }
                }

                self.emissionList.removeAll { $0.name.contains("MIL") }
                self.emissionList.forEach { rediness in
                    if !rediness.complete {
                        self.fail = self.fail + 1
                    }
                }

                self.postOBDData { _, _ in }
                callback(self.emissionList)
            } catch {
                // ignore error
            }
        }
        rc.requestReadinessMonitors(reqType: 3)
    }

    public func checkPassFailEmission() -> String {
        let nonComplete = emissionList.filter { !$0.complete }

        if emissionList.isEmpty || emissionList.count <= 5 {
            passFail = ""
            return ""
        }

        if fuelType == "Gasoline" {
            let name = nonComplete.filter { $0.name == "Evaporative System" }
            passFail = (nonComplete.count == 1 && !name.isEmpty) ? "PASS" :
                (nonComplete.count == 1 && name.isEmpty) ? "FAIL" :
                (nonComplete.count > 1) ? "FAIL" : "PASS"
        } else {
            let name = nonComplete.filter { $0.name.contains("EGR/VVT System") || $0.name.contains("NMHC Catalyst") }
            passFail = (nonComplete.count >= 1 && name.isEmpty) ? "FAIL" :
                (nonComplete.count == 2 && name.count == 2) ? "PASS" :
                (nonComplete.count == 1 && name.count == 1) ? "PASS" :
                (nonComplete.count > 2) ? "FAIL" : "PASS"
        }

        return passFail
    }

    public func getRecentCodeReset(
        callbackWarmUpCycle: @Sendable @escaping (String) -> Void,
        callbackDistanceSinceCodeCleared: @Sendable @escaping (String) -> Void,
        callbackTimeSinceCodeCleared: @Sendable @escaping (String) -> Void
    ) {
        clearCodesReset()
        warmUpCyclesSinceCodesCleared { callbackWarmUpCycle($0) }
        distanceSinceCodesCleared { callbackDistanceSinceCodeCleared($0) }
        timeSinceTroubleCodesCleared { callbackTimeSinceCodeCleared($0) }
    }

    func warmUpCyclesSinceCodesCleared(callback: @Sendable @escaping (String) -> Void) {
        rc.requestDataPoint(pid: "0130") { [weak self] result in
            guard let self = self else { return }
            let scientificNotation = self.getScientificNotation(inputString: result)
            self.warmUpCyclesSinceCodesCleared = Double(scientificNotation) ?? 0.0
            self.warmUpCyclesSinceCodesClearedStr = self.warmUpCyclesSinceCodesCleared == 0.0 ? "-" : "\(Int(self.warmUpCyclesSinceCodesCleared))"
            callback(self.warmUpCyclesSinceCodesClearedStr)
        }
    }

    func distanceSinceCodesCleared(callback: @Sendable @escaping (String) -> Void) {
        rc.requestDataPoint(pid: "0131") { [weak self] result in
            guard let self = self else { return }
            let notation = self.getScientificNotation(inputString: result)
            let distanceDouble = (Double(notation) ?? 0.0) / 1.609
            self.distanceSinceCodesCleared = Int(distanceDouble)
            self.distanceSinceCodesClearedStr = self.distanceSinceCodesCleared == 0 ? "-" : "\(self.distanceSinceCodesCleared)"
            callback(self.distanceSinceCodesClearedStr)
        }
    }

    func timeSinceTroubleCodesCleared(callback: @Sendable @escaping (String) -> Void) {
        rc.requestDataPoint(pid: "014E") { [weak self] result in
            guard let self = self else { return }
            let notation = self.getScientificNotation(inputString: result)
            let timeDouble = (Double(notation) ?? 0.0) / 60
            self.timeSinceTroubleCodesCleared = Int(timeDouble)
            self.timeSinceTroubleCodesClearedStr = self.timeSinceTroubleCodesCleared == 0 ? "-" : "\(self.timeSinceTroubleCodesCleared)"
            callback(self.timeSinceTroubleCodesClearedStr)
        }
    }

    public func clearCodesReset() {
        warmUpCyclesSinceCodesCleared = 0.0
        warmUpCyclesSinceCodesClearedStr = "-"
        distanceSinceCodesCleared = 0
        distanceSinceCodesClearedStr = "-"
        timeSinceTroubleCodesCleared = 0
        timeSinceTroubleCodesClearedStr = "-"
    }

    func timeRunWithMILOn(callback: @Sendable @escaping (String) -> Void) {
        rc.requestDataPoint(pid: "014D") { [weak self] result in
            guard let self = self else { return }
            self.timeRunWithMILOnStr = "-"
            let notation = self.getScientificNotation(inputString: result)
            let timeDouble = (Double(notation) ?? 0.0) / 60
            self.timeRunWithMILOn = Int(timeDouble)
            self.timeRunWithMILOnStr = self.timeRunWithMILOn == 0 ? "-" : "\(self.timeRunWithMILOn)"
            callback(self.timeRunWithMILOnStr)
        }
    }

    func getScientificNotation(inputString: String) -> String {
        guard !inputString.isEmpty, let sciNotationValue = Double(inputString) else {
            return ""
        }
        return "\(Int(sciNotationValue.rounded()))"
    }

    public func isManualResetSuspected() -> Int {
        if warmUpCyclesSinceCodesClearedStr == "-" || distanceSinceCodesClearedStr == "-" {
            return -1
        } else if distanceSinceCodesCleared >= 100 && warmUpCyclesSinceCodesCleared > 25 {
            return 1
        } else {
            return 0
        }
    }

    // MARK: - stop / getRepairCostSummary
    public func stopAdvanceScan() {
        self.rc.stopTroubleCodeScan()
    }

    public func getRepairCostSummary(vinNumber: String, dtcErrorCodeArray: [DTCResponseModel]) {
        guard !dtcErrorCodeArray.isEmpty else {
            connectionListner?.didReceiveRepairCost(result: nil)
            return
        }

        // use actor-backed processDtcCodes to ensure safety if needed
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.processDtcCodes(vinNumber: vinNumber, dtcErrorCodeArray: dtcErrorCodeArray)
            
        }
    }

    // MARK: - postOBDData (unchanged)
    private func postOBDData(completion: @Sendable @escaping (Bool, String?) -> Void) {

        guard let url = URL(string: Constants.BASE_URL + "update") else {
            print("Invalid URL")
            completion(false, "Invalid URL")
            return
        }

        // Build readiness array
        var redinessArray: [[String: Any]] = []
        self.emissionList.forEach { rediness in
            var item: [String: Any] = [:]
            item["description"] = rediness.des
            item["available"] = rediness.available
            item["complete"] = rediness.complete
            item["name"] = rediness.name
            item["finalstatus"] = checkPassFailEmission()
            redinessArray.append(item)
        }

        var codereset: [String: Any] = [:]
        codereset["warm_up_cycles_since_codes_cleared"] = self.warmUpCyclesSinceCodesClearedStr
        codereset["distance_since_codes_cleared"] = self.distanceSinceCodesClearedStr
        codereset["time_since_trouble_codes_cleared"] = self.timeSinceTroubleCodesClearedStr
        codereset["time_run_with_MIL_on"] = self.timeRunWithMILOnStr
        codereset["suspicion_level"] = isManualResetSuspected()
        if isManualResetSuspected() == 0 {
            codereset["suspicion_passfail"] = "FAIL"
        } else if isManualResetSuspected() == 1 {
            codereset["suspicion_passfail"] = "PASS"
        } else {
            codereset["suspicion_passfail"] = "N/A"
        }

        var recallHis: [[String: Any]] = []
        if let recallResponse = recallResponse {
            recallResponse.results.forEach { recall in
                var item: [String: Any] = [:]
                if isAutoRecall {
                    item["NHTSACampaignNumber"] = recall.nhtsaCampaignNumber ?? "N/A"
                    item["NHTSAActionNumber"] = recall.mfgCampaignNumber ?? "N/A"
                    item["ReportReceivedDate"] = recall.nhtsaRecallDate ?? "N/A"
                    item["Component"] = recall.componentDescriptionrecall
                    item["Remedy"] = recall.correctiveSummary ?? "N/A"
                    item["Notes"] = recall.recallNotes ?? "N/A"
                    item["StopSale"] = (recall.stopSale?.uppercased() == "YES") ? "YES" : "-"
                    item["Summary"] = recall.subject ?? recall.defectSummary ?? "N/A"
                    item["Consequence"] = recall.consequenceSummary ?? "N/A"
                } else {
                    if let actionNumber = recall.actionNumber, !actionNumber.isEmpty {
                        item["NHTSAActionNumber"] = actionNumber
                    }
                    item["NHTSACampaignNumber"] = recall.campaignNumber ?? "N/A"
                    item["ReportReceivedDate"] = recall.reportReceivedDate ?? "N/A"
                    item["Component"] = recall.component ?? "N/A"
                    item["Summary"] = recall.summary ?? "N/A"
                    item["Consequence"] = recall.consequence ?? "N/A"
                    item["Remedy"] = recall.remedy ?? "N/A"
                    item["Notes"] = recall.notes ?? "N/A"
                }
                recallHis.append(item)
            }
        }

        let body: [String: Any] = [
            "scan_id": scanID,
            "code_reset": codereset,
            "emmission": redinessArray,
            "recall_history": recallHis
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            print("Error encoding JSON")
            completion(false, "JSON encoding error")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(self.variableData?.accessToken ?? "", forHTTPHeaderField: "access-token")
        request.addValue(self.variableData?.serverKey ?? "", forHTTPHeaderField: "server-key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            guard let data = data else {
                completion(false, "No data")
                return
            }
            let responseText = String(data: data, encoding: .utf8)
            completion(true, responseText)
        }.resume()
    }
    
    
    public func getDeviceFirmwareVersion() -> Result<String?, Error>? {

        let result = self.rc.getDeviceFirmwareVersion()

 
        currentFirmwareVersion = (try? result.get()) ?? ""

        return result
    }

}

// MARK: - Extensions
extension VINDetailResult {
    func toMap() -> [String: String] {
        var resultMap = [String: String]()
        let mirror = Mirror(reflecting: self)

        for child in mirror.children {
            if let propertyName = child.label,
               let propertyValue = child.value as? CustomStringConvertible {
                let valueString = propertyValue.description
                if !valueString.isEmpty {
                    resultMap[propertyName] = valueString
                }
            }
        }

        return resultMap
    }
}

extension Array {
    func distinctBy<T: Hashable>(_ key: (Element) -> T) -> [Element] {
        var seen: Set<T> = []
        return self.filter { element in
            let keyValue = key(element)
            return seen.insert(keyValue).inserted
        }
    }
}
extension JSON: @unchecked @retroactive Sendable {}

struct StreamSample {
    let ecuKey: String
    let valueKey: String
    let title: String
    let ecuName: String
    let unit: String
    let timestamp: Date
    let displayValue: String
}
final class DtcProcessingState: @unchecked Sendable {
    var jsonResponses: [[String: Any]] = []
    var successful: Int = 0
    var failed: Int = 0
}
struct SendableDict: @unchecked Sendable {
    let value: [String: Any]
}
