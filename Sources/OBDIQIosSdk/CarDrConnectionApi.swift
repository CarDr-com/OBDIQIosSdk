//
//  CarDrConnectionApi.swift
//  test
//
//  Created by Arvind Mehta on 07/04/23.
//

import Foundation
import RepairClubSDK
import CoreBluetooth
import SwiftyJSON


@available(iOS 13.0.0, *)
public class CarDrConnectionApi {
    
    public init() { } 
   
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
    private var  variableData:VariableData? = nil
    private var recallResponse:RecallResponse? = nil
    var scanID = ""
    var isMilOn = false
    var dictonary = [String: Any]()
    var connectionStates: [ConnectionStage: ConnectionState] = [:]
    var isAutoRecall = false

    public var connectionHandler: ((ConnectionEntry, ConnectionStage, ConnectionState?) -> Void)? = nil

    var vinNumber = ""
    var hardwareIdentifier = ""
    // MARK: - Initial Function to Initialize the SDK
    public func initialConnect(listener: ConnectionListener) {
        self.connectionListner = listener
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        getVariable { it in
           
            self.rc.configureSDK(
                tokenString: it?.repairClubToken ?? "",
                appName: "OBDIQ ULTRA SDK",
                appVersion: appVersion,
                userID: "support@cardr.com"
            )
            self.connectionListner?.didScanForDevice(startScan: true)
        }
       
        
    }
    
    
    private func getVariable(completion: @escaping (VariableData?) -> Void) {

        guard let url = URL(string: Constants.GET_VARIABLE_URL) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("edf9bc2d74ad74ac924c9bcbc337ef62", forHTTPHeaderField: "access-token")
        request.addValue("a4d01210f164259f3ed2f1072f0819d5", forHTTPHeaderField: "server-key")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                print("API Error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    let jsonValue = JSON(json)
                    let responseObj = VariableData(json: jsonValue)
                    

                    DispatchQueue.main.async {
                        self.variableData = responseObj
                        completion(responseObj)
                    }
                }
            } catch {
                print("JSON decode error: \(error.localizedDescription)")
                completion(nil)
            }
        }

        task.resume()
    }

    
    private func getConfigValues(completion: @escaping (Configuration) -> Void){
        guard let url = URL(string: "") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 🔹 Add headers (same style as your POST example)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("edf9bc2d74ad74ac924c9bcbc337ef62", forHTTPHeaderField: "access-token")
        request.addValue("a4d01210f164259f3ed2f1072f0819d5", forHTTPHeaderField: "server-key")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                print("Recall API error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data returned")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let jsonValue = JSON(json)
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
  
    //MARK  Call this function to disconnect the Mobile device with OBD adapter
    public  func dissconnectOBD(){
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
    
//   private func loadAdvancedValueCatalog() -> [RepairClubSDK.AVECU] {
//        let catalog = rc.advancedValueOperationCatalog(set: "avr_transmission_test")
//
//       
//          return catalog
//      }
//   
//  
//    private func buildKeys(from catalog: [RepairClubSDK.AVECU]) -> [(ecuKey: String, valueKey: String, valueName: String, unit: String, ecuName: String)] {
//        var keys: [(String, String, String, String, String)] = []
//
//        for ecu in catalog {
//            
//            if !ecu.name.lowercased().contains("odometer") {
//                for value in ecu.values {
//                   
//                    keys.append((ecu.key, value.key, value.name, value.unit ?? "", ecu.name))
//                }
//          }
//        }
//
//        return keys
//    }
//
//
//
// 
//
//   
//
//    private func
//    
//    startStreaming(from catalog: [RepairClubSDK.AVECU],
//                        onUpdate: @escaping ([StreamSample]) -> Void) {
//        let keys = buildKeys(from: catalog)
//
//        // Pre-fill samples with placeholders using value.name for title
//        var samples = keys.map { (ecuKey, valueKey, valueName,unit,ecuName) in
//            StreamSample(
//                ecuKey: ecuKey,
//                valueKey: valueKey,
//                title: valueName,
//                ecuName: ecuName,
//                unit: unit,
//                timestamp: Date(),
//                displayValue: "Waiting..."
//            )
//        }
//
//        // Flatten keys to pass into SDK
//        let flatKeys = keys.map { ($0.ecuKey, $0.valueKey) }
//
//        rc.advancedValueStartStreaming(keys: flatKeys) { readings in
//            for reading in readings {
//                let ecuKey = reading.ecuKey
//                let valueKey = reading.valueKey
//              
//
//                for sample in reading.values {
//                    let timestamp = sample.date
//                    let displayValue: String
//
//                    switch sample.value {
//                    case .number(let d):
//                        displayValue = "\(d)"
//                    case .text(let s),
//                         .enumeration(let s),
//                         .raw(let s):
//                        displayValue = s
//                    case .noData:
//                        displayValue = "N/A"
//                    case .nrc(let code):
//                        displayValue = "Unavailable (\(code))"
//                    @unknown default:
//                        displayValue = "Unknown"
//                    }
//                    
//                    if displayValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
//                                    displayValue == "0" || displayValue == "0.0" {
//                                    continue
//                                }
//                    let preciseDate = Date()
//                    // Find index in samples
//                    if let index = samples.firstIndex(where: {
//                        $0.ecuKey == ecuKey && $0.valueKey == valueKey
//                    }) {
//                       
//                        let existing = samples[index]
//                        samples[index] = StreamSample(
//                            ecuKey: ecuKey,
//                            valueKey: valueKey,
//                            title: existing.title,
//                            ecuName: existing.ecuName,
//                            unit: existing.unit,
//                            timestamp: preciseDate,
//                            displayValue: displayValue
//                        )
//                    }
//                }
//            }
//
//            onUpdate(samples)
//           
//        }
//    }

    
    
    public  func scanForDevice() {
        
            rc.returnDevices { result in
                switch result {
                case .success(let devices):
                  
                    self.connectionListner?.didDevicesFetch(foundedDevices: devices)
                    if let nearestDevice = devices.sorted(by: { $0.rssi >
                        $1.rssi }).first {
                        
                        self.connectPeripheral(peripheral: nearestDevice.device)
                    }
                    break
                case .failure(let error):
                    break
                @unknown default:break
                    
                }
            }

    }
    
    
    //MARK   Connect OBD using bluetooth
    //  vehicleEntry  Obj  will return the vehical related data
    func connectPeripheral(peripheral:CBPeripheral?){
        
      
        if(peripheral == nil){
            return
        }
        connectionStates.removeAll()
        self.rc.connectToDevice(peripheral: peripheral!) { [self] connectionEntry, connectionstage, connectionState in
           
                connectionStates[connectionstage] = connectionState
            


            self.connectionEntry = connectionEntry
            self.connectionHandler?(connectionEntry, connectionstage, connectionState)
            self.connectionListner?.didCheckScanStatus(status: "\(connectionstage)")
            switch connectionstage {
            case .deviceHandshake:
                print("Connection: deviceHandshake - \(connectionState)")
                switch connectionState {
                case .completed:
                    if let device = connectionEntry.deviceItem{
                        hardwareIdentifier = device.hardwareIdentifier ?? device.deviceIdentifier
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
                       
                        if(vin.isEmpty){
                          
                          
                           
                        }
                        
                       
                      
                    }
                    
                default: break
                }
            case .vehicleDecoded:
                                 if let vehicleEntry = connectionEntry.vehicleEntry {
                                  
                                     carName = vehicleEntry.shortDescription
                                     yearstr = vehicleEntry.yearString
                                     make = vehicleEntry.make
                                     model = vehicleEntry.model
                                     vinNumber = vehicleEntry.VIN

                                     let entry = VehicleEntries()
                                     entry.VIN = vehicleEntry.VIN
                                     entry.shortDescription = vehicleEntry.shortDescription
                                     entry.make = vehicleEntry.make
                                     entry.model = vehicleEntry.model
                                     entry.description = vehicleEntry.description
                                     entry.engine = vehicleEntry.engine
                                     entry.vehiclePowertrainType = vehicleEntry.vehiclePowertrainType?.rawValue ?? "Unknown"

                                     // Invoke listener safely
                                     connectionListner?.didFetchVehicleInfo(vehicleEntry: entry)

                                    
                                     
                                   
                                 } else if let vin = connectionEntry.vin {
                                     let vinNumber = vin
                                 }
            case .configDownloaded:
                self.isConnected = true
                switch connectionState {
                case .completed:print("Complete")
                    
                case .failed (let error):
                     
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
       
                case .manuallyEntered, .started, .notStarted: break
                   
                @unknown default:
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
                }
               
                   
                

               
            case .busSyncedToConfig:
                switch connectionState {
                case .completed:
                    self.connectionListner?.isReadyForScan(status: true,isGeneric: false)
                case .failed(let error):
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
                   
                case .manuallyEntered, .started, .notStarted: break
                 
                @unknown default:
                   
                    self.connectionListner?.isReadyForScan(status: true, isGeneric: true)
                    }
               
               
            case .milChecking:
                if !isMilOn {
                    if connectionState == .completed, let milStatus = connectionEntry.milOn {
                        isMilOn = milStatus
                    }
                }

                self.connectionListner?.didFetchMil(mil: isMilOn)

            case .readinessMonitors:
                print("Connection: readinessMonitors - \(connectionState)")
            case .supportedPIDsReceived:
                print("Connection: supportedPIDsReceived - \(connectionState)")
            case .supportedMIDsReceived:
                print("Connection: supportedMIDsReceived - \(connectionState)")
            case .odometerReceived:print("Connection: ODOMETER - \(connectionEntry.odometer)")
                
            @unknown default: break
               
            }
        }
        
        
    }
    
    
    public func startScan() {
        scanID = ""
       

        if let state = connectionStates[.configDownloaded], case .failed = state {
            startAdvanceScan(advancescan: false)
        }

        if connectionStates[.busSyncedToConfig] == .completed {
            startAdvanceScan()
        } else if let state = connectionStates[.busSyncedToConfig], case .failed = state {
            startAdvanceScan(advancescan: false)
        }
    }

    
    
    
    //MARK  Call this function  to get the Vehical Detail
    
    
    
 
    var fail = 0
    func startAdvanceScan(advancescan:Bool = true) {
       
        
        var strArr = [String]()
        
        rc.startTroubleCodeScan(advancedScan: advancescan) { [self] progressupdate in
            switch progressupdate {
                
            case .scanStarted: break
            case .progressUpdate(let progress):
              
                var per = ceil(progress*100)/100
                
                let percent = String(format: "%.2f", per * 100)
                
                self.connectionListner?.didUpdateProgress(progressStatus: "progressupdate", percent: percent)
            case .moduleScanningUpdate(moduleName: let moduleName):
                print("ModuleName ======= \(moduleName)")
            case .modulesUpdate(modules: let modulesUpdate):print("")
            
                
            case .scanSucceeded( modules: let modulesUpdate,scanEntry: let scanEntry, errors: let errors):
               
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
               
                       
                // Get distinct modules by name
                var dtcErrorCodeList = [DTCResponseModel]()
                        // Get distinct modules by name
                       
                        
                        for module in distinctModules {
                            let moduleName = module.name
            
                            var dtcResponse = DTCResponseModel()
                            dtcResponse.id = module.id.uuidString
                            dtcResponse.moduleName = module.name
                            dtcResponse.responseStatus = module.responseStatus.description
                            dtcResponse.identifier = module.identifier
                            
                            // Get distinct codes and map to DTCResponse
                            let codesList = module.codes
                                .distinctBy { $0.code }
                                .map { code in
                                    var dtc = DTCResponse()
                                    dtc.dtcErrorCode = code.code
                                    dtc.status = code.statusesDescription
                                    dtc.desc = code.description ?? ""
                                    dtc.name = moduleName // Assigning name directly here
                                    return dtc // Return the DTCResponse object
                                }
                            
                            dtcResponse.dtcCodeArray = Array(codesList) // Convert to array
                            dtcErrorCodeList.append(dtcResponse) // Append to the list
                            
                        }
                    self.dtcErrorCodeArray.removeAll()
                let distinctArray = dtcErrorCodeList.distinctBy { $0.moduleName }
                distinctArray.forEach { model in
                    model.removeDuplicateDTCResponses()
                }
                self.dtcErrorCodeArray.append(contentsOf: distinctArray)
                
                self.connectionListner?.didReceivedCode(model: self.dtcErrorCodeArray)
                
         
                callScanApi()
               
              
              
                
                
                
            case .scanFailed(errors: let errors):break
               
            @unknown default:break
                
            }
        }
    }
   
    @MainActor
    func clearCode(completion: @escaping (OperationProgressUpdate) -> Void) {

        Task { [weak self] in
            guard let self = self else { return }

            if !self.isConnected {

                // 1. Return devices
                rc.returnDevices { result in
                    switch result {

                    case .success(let devices):
                        guard let nearestDevice = devices.sorted(by: { $0.rssi > $1.rssi }).first,
                              let device = nearestDevice.device else { return }

                        // 2. Connect to device
                        self.rc.connectToDevice(peripheral: device) { [weak self]
                            connectionEntry, connectionStage, connectionState in

                            guard let self = self else { return }
                            self.isConnected = true

                            if connectionStage == .vinReceived {
                                switch connectionState {

                                case .completed, .failed(_):

                                    Task { [weak self] in
                                        guard let self = self else { return }

                                        // 1 second delay safely
                                        try await Task.sleep(nanoseconds: 1_000_000_000)

                                        do {
                                            try self.rc.clearAllCodes { progress in
                                                Task { @MainActor in
                                                    completion(progress)
                                                }
                                            }
                                        } catch {
                                            print("Error clearing codes: \(error)")
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

                    do {
                        try self.rc.clearAllCodes { progress in
                            Task { @MainActor in
                                completion(progress)
                            }
                        }
                    } catch {
                        print("Error clearing codes: \(error)")
                    }
                }
            }
        }
    }

    func getRecall(autoapRecall:Bool = false,completion: @escaping (RecallResponse) -> Void) {
        // Ensure safety recall feature is enabled
        isAutoRecall = autoapRecall
        //if autoapRecall == true {
            // New API: VIN-based recall lookup
            recallRepairSummary(vinNumber: vinNumber) { response in
                self.recallResponse = response
                self.postOBDData { _,_ in
                    
                }
                completion(response)
            }
//        } else {
//            // Old API: Make/Model/Year recall lookup
//            recallRepairSummary(make: make,
//                                   model: model,
//                                   year: yearstr) { response in
//                self.recallResponse = response
//                self.postOBDData { _,_ in
//                    
//                }
//                completion(response)
//            }
//        }
    }
    
    func recallRepairSummary(
        make: String,
        model: String,
        year: String,
        completion: @escaping (RecallResponse) -> Void
    ) {
        guard let nhtsaUrl = variableData?.nhtsaUrl,
                  let recallApi = variableData?.recallApi else {
                print("❌ Missing API URL components")
                return
            }

        let urlString = "\(nhtsaUrl)\(recallApi)?make=\(make)&model=\(model)&modelYear=\(year)"


        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 🔹 Add headers (same style as your POST example)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(variableData?.recallToken ?? "", forHTTPHeaderField: "Authorization")
        request.addValue("OBD SDK", forHTTPHeaderField: "App-Type")
        request.addValue("edf9bc2d74ad74ac924c9bcbc337ef62", forHTTPHeaderField: "access-token")
        request.addValue("a4d01210f164259f3ed2f1072f0819d5", forHTTPHeaderField: "server-key")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                print("Recall API error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data returned")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    // Convert dictionary → SwiftyJSON.JSON
                            let json = JSON(json)

                            // Create response object
                            var response = RecallResponse(json: json)

                            // Sort results by recallDate
                            response.results.sort {
                                guard let d1 = $0.recallDate(), let d2 = $1.recallDate() else { return false }
                                return d1 > d2
                            }

                            // Return on main thread
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

    
    func recallRepairSummary(
        vinNumber: String,
        completion: @escaping (RecallResponse) -> Void
    ) {
        guard let nhtsaUrl = variableData?.autoAppUrl
        else {
                print("❌ Missing API URL components")
                return
            }

        let urlString = "\(nhtsaUrl)/\(vinNumber)"

        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 🔹 Add headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(variableData?.recallToken ?? "", forHTTPHeaderField: "Authorization")
        request.addValue("ReactApp", forHTTPHeaderField: "App-Type")
        request.addValue("edf9bc2d74ad74ac924c9bcbc337ef62", forHTTPHeaderField: "access-token")
        request.addValue("a4d01210f164259f3ed2f1072f0819d5", forHTTPHeaderField: "server-key")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("Error fetching recall: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("Empty response")
                return
            }

            do {
               // if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let responseText = String(data: data, encoding: .utf8)
                print(responseText)
                    let json = JSON(data)

                    // Create response object
                    var response = RecallResponse(json: json)

                    // 🔹 Only safety recalls (V)
                    var filtered = response.results.filter { $0.isSafetyRecall() }

                    // 🔹 Sort by date descending
                    filtered.sort {
                        guard let d1 = $0.recallDate(), let d2 = $1.recallDate() else { return false }
                        return d1 > d2
                    }

                    response.results = filtered

                    DispatchQueue.main.async {
                        completion(response)
                    }
               // }
            } catch {
                print("JSON error: \(error.localizedDescription)")
            }
        }

        task.resume()
    }

    
    
    func separateArrays(response: DTCResponse, moduleName: String) -> (String, String, String) {
        let cat = getResponseFromJSON(msg: moduleName)
        
        let status = response.status.lowercased()
        let attentionStatuses = ["active", "current", "permanent", "warning light"]
        
        if attentionStatuses.contains(status) || status.contains("confirmed") {
            return ("Attention", "", cat)
        } else {
            return ("INFORMATIONAL", "INFORMATIONAL", cat)
        }
    }

    let sampleMap: [String: String] = [
        "modgenericule": "Performance & Compliance",
        "generic codes": "Other & Non Categorized",
        "electric power steering": "Safety & Operability",
        "drive door motor": "Comfort & Convenience"
    ]

    func getResponseFromJSON(msg: String) -> String {
        return sampleMap[msg] ?? "Other & Non Categorized"
    }
    
    func getCurrentDateFormatted() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy h:mm a"
        dateFormatter.locale = Locale.current
        return dateFormatter.string(from: Date())
    }


    func callScanApi() {
        
       
        guard !vinNumber.isEmpty else {
            print("callScanApi: VIN number is empty")
            return
        }

        let dtcArr = dtcErrorCodeArray.flatMap { model -> [[String: Any]] in
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

        // Count generic and OEM DTC codes
        let (genericCount, oemCount) = dtcErrorCodeArray
            .reduce(into: (0, 0)) { counts, model in
                let isGeneric = model.moduleName.localizedCaseInsensitiveContains("generic") == true ||
                model.moduleName.localizedCaseInsensitiveContains("standard") == true
                
                if isGeneric {
                    counts.0 += model.dtcCodeArray.count  // genericCount
                } else {
                    counts.1 += model.dtcCodeArray.count  // oemCount
                }
            }

        // Get unique module names, excluding "generic" and "standard"
      

        var controllerArr = [String]()
        let filteredModules = filterModules(filterNonGenericModules(self.controller))
        filteredModules.forEach { item in
            controllerArr.append(item.name)
        }

        let parameters: [String: Any] = [
            "modules": controllerArr,
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
        
        guard let scan = variableData?.scan
        else {
                print("❌ Missing API URL components")
                return
            }


        guard let url = URL(string: Constants.BASE_URL + scan) else {
            print("Invalid URL")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("edf9bc2d74ad74ac924c9bcbc337ef62", forHTTPHeaderField: "access-token")
            request.addValue("a4d01210f164259f3ed2f1072f0819d5", forHTTPHeaderField: "server-key")
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("callScanApi: API Call failed: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    print("callScanApi: No response data")
                    return
                }

                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
//                       let dataDict = jsonResponse["data"] as? [String: Any],
//                       let scanId = dataDict["id"] as? String,
//                       !scanId.isEmpty
                    {
                        let json = JSON(jsonResponse)
                        let id = json["data"]["id"].stringValue
                        self.scanID = id
                        print("callScanApi: Response Scan ID: \(id)")

                        self.getEmissionMonitors { emissionArray in
                            // handle
                        }

                        self.getRecall(autoapRecall: false) { response in
                            // handle
                        }
                    }

                } catch {
                    print("callScanApi: JSON Parsing Error: \(error.localizedDescription)")
                }
            }
            task.resume()
        } catch {
            print("callScanApi: JSON Encoding Error: \(error.localizedDescription)")
        }
    }

    private func filterNonGenericModules(_ modules: [ModuleItem]) -> [ModuleItem] {
        return modules.filter {
            !$0.name.lowercased().contains("generic") && $0.name != "Standard Codes"
        }
    }
    private func filterModules(_ modules: [ModuleItem]) -> [ModuleItem] {
        return modules.filter {
            $0.responseStatus == .responded
        }
    }
    private func sortModules(modules: [RepairClubSDK.ModuleItem]) -> [RepairClubSDK.ModuleItem] {
        return modules.sorted {
            if $0.name.contains("Generic Codes") { return true }
            if $1.name.contains("Generic Codes") { return false }
            
            let responseOrder: [ResponseStatus: Int] = [.responded: 1, .awaitingDecode: 2, .didNotRespond: 3, .unknown: 4]
            if responseOrder[$0.responseStatus]! < responseOrder[$1.responseStatus]! { return true }
            if responseOrder[$0.responseStatus]! > responseOrder[$1.responseStatus]! { return false }
            
            if !$0.codes.isEmpty && $1.codes.isEmpty { return true }
            if $0.codes.isEmpty && !$1.codes.isEmpty { return false }
            
            return $0.name < $1.name
        }
    }

    private func handleModulesUpdate(modules: [RepairClubSDK.ModuleItem]) {
        // Handle module updates here if needed
    }

    public func getEmissionMonitors(callback: @escaping (_ emissions: [EmissionRediness]) -> Void) {
            isReadinessComplete = false
            emissionList.removeAll()
            
       
            rc.subscribeToMonitors { str in
                do {
                    self.emissionList.removeAll()
                    let data = try str.get()
                    data.forEach { monitor in
                        
                        if(monitor.readinessStatus?.first != nil){
                            if(monitor.readinessStatus!.first!){
                                    self.emissionList.append(EmissionRediness(name: monitor.valueName, available: monitor.readinessStatus?.first ?? false, status: monitor.readinessStatus?.last ?? false ,desc: monitor.description))
                                
                            }
                        }
                        
                    }
                 
                    self.emissionList.removeAll { $0.name.contains("MIL") }

                    self.emissionList.forEach { rediness in
                        if(!rediness.complete){
                            self.fail = self.fail + 1
                        }
                    }
                
                    self.postOBDData(completion:
                                        {_,_ in 
                        
                    })
                    callback(self.emissionList)
                   
                } catch {
                    // Handle error here
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
            callbackWarmUpCycle: @escaping (String) -> Void,
            callbackDistanceSinceCodeCleared: @escaping (String) -> Void,
            callbackTimeSinceCodeCleared: @escaping (String) -> Void
        ) {
            clearCodesReset()
            
            warmUpCyclesSinceCodesCleared { callbackWarmUpCycle($0) }
            distanceSinceCodesCleared { callbackDistanceSinceCodeCleared($0) }
            timeSinceTroubleCodesCleared { callbackTimeSinceCodeCleared($0) }
        }
    
     func warmUpCyclesSinceCodesCleared(callback: @escaping (String) -> Void) {
        rc.requestDataPoint(pid: "0130") { result in
               
                let scientificNotation = self.getScientificNotation(inputString: result)
                self.warmUpCyclesSinceCodesCleared = Double(scientificNotation) ?? 0.0
                self.warmUpCyclesSinceCodesClearedStr = self.warmUpCyclesSinceCodesCleared == 0.0 ? "-" : "\(Int(self.warmUpCyclesSinceCodesCleared))"
                
                callback(self.warmUpCyclesSinceCodesClearedStr)
            }
        }

         func distanceSinceCodesCleared(callback: @escaping (String) -> Void) {
            rc.requestDataPoint(pid: "0131") { result in
               
                let notation = self.getScientificNotation(inputString: result)
                let distanceDouble = (Double(notation) ?? 0.0) / 1.609
                self.distanceSinceCodesCleared = Int(distanceDouble)
                self.distanceSinceCodesClearedStr = self.distanceSinceCodesCleared == 0 ? "-" : "\(self.distanceSinceCodesCleared)"
                
                callback(self.distanceSinceCodesClearedStr)
            }
        }

         func timeSinceTroubleCodesCleared(callback: @escaping (String) -> Void) {
            rc.requestDataPoint(pid: "014E") { result in
               
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

     func timeRunWithMILOn(callback: @escaping (String) -> Void) {
        rc.requestDataPoint(pid: "014D") { result in
               

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
    
    
    
        
    
    public func stopAdvanceScan(){
        self.rc.stopTroubleCodeScan()
    }
    
    
    public func getRepairCostSummary(vinNumber: String, dtcErrorCodeArray: [DTCResponseModel], callback: @escaping (Bool, [String: Any]?) -> Void) {
        guard !dtcErrorCodeArray.isEmpty else {
            callback(false, nil)
            return
        }
        
        processDtcCodes(vinNumber: vinNumber, dtcErrorCodeArray: dtcErrorCodeArray) { status, json in
            callback(status, json)
        }
    }

    func processDtcCodes(
        vinNumber: String,
        dtcErrorCodeArray: [DTCResponseModel],
        callback: @escaping (Bool, [String: Any]?) -> Void
    ) {
        var dtcArr = [[String: String]]()

        // Collect unique DTC codes
        for model in self.dtcErrorCodeArray {
            let module = model.moduleName
            for dtc in model.dtcCodeArray {
                let status = dtc.status.lowercased()
            
                    if ((status.contains("active") || status.contains( "confirmed"))  || status.contains("permanent")) {
                    let removedSpecial = dtc.desc.replacingOccurrences(
                        of: "[^a-zA-Z0-9 .,]",
                        with: "",
                        options: .regularExpression
                    )

                    // Step 2: Replace multiple whitespace with single space
                    let collapsedSpaces = removedSpecial.replacingOccurrences(
                        of: "\\s+",
                        with: " ",
                        options: .regularExpression
                    )
                    dtcArr.append([
                        "code": dtc.dtcErrorCode,
                        "module": module,
                        "code_desc":collapsedSpaces
                    ])
                }
            }
        }

        guard !scanID.isEmpty else {
            callback(false, nil)
            return
        }

        let dtcArrChunkSize = 5
        let dtcArrChunks = stride(from: 0, to: dtcArr.count, by: dtcArrChunkSize).map {
            Array(dtcArr[$0..<min($0 + dtcArrChunkSize, dtcArr.count)])
        }
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue(label: "com.repairCostManager.syncQueue", attributes: .concurrent)
        var successfulChunks = 0
        var failedChunks = 0

        var jsonResponses: [[String: Any]] = []
        guard let repairInfo = variableData?.repairInfo
        else {
                print("❌ Missing API URL components")
                return
            }
        for chunk in dtcArrChunks {
            dispatchGroup.enter()
            let chunkParams: [String: Any] = ["dtcCode": chunk, "vin": vinNumber]

            callApiJSON(url: Constants.BASE_URL + repairInfo, params: chunkParams) { status, response in
                queue.async(flags: .barrier) { // Ensures thread safety
                    if status, let jsonData = response {
                        jsonResponses.append(jsonData) // Store successful response
                        successfulChunks += 1
                    } else {
                        failedChunks += 1
                    }
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            queue.sync {
                if failedChunks == dtcArrChunks.count {
                    callback(false, nil)
                } else {
                    let mergedJson = jsonResponses.reduce(into: [String: Any]()) { result, dict in
                        result.merge(dict) { _, new in new }
                    }

                    self.postRepairCost(dtcErrorCodeArray: dtcErrorCodeArray, jsonObject: mergedJson)
                    callback(true, mergedJson)
                }
            }
        }

    }
    
    private func callApiJSON(url: String, params: [String: Any], callback: @escaping (Bool, [String: Any]?) -> Void) {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []) else {
                callback(false, nil)
                return
            }

            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
           request.addValue("edf9bc2d74ad74ac924c9bcbc337ef62", forHTTPHeaderField: "access-token")
           request.addValue("a4d01210f164259f3ed2f1072f0819d5", forHTTPHeaderField: "server-key")
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("API Error: \(error.localizedDescription)")
                    callback(false, nil)
                    return
                }
                guard let data = data else {
                    callback(false, nil)
                    return
                }
                
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    callback(true, jsonResponse)
                } else {
                    callback(false, nil)
                }
            }
            task.resume()
        }

        private func postRepairCost(dtcErrorCodeArray: [DTCResponseModel], jsonObject: [String: Any]?) {
            guard !scanID.isEmpty, !dtcErrorCodeArray.isEmpty else { return }

            let response = makeJsonOfResponse(jsonObject: jsonObject)
            guard let repaircost = variableData?.repairCost
            else {
                    print("❌ Missing API URL components")
                    return
                }
            callApiJSON(url: Constants.BASE_URL + repaircost, params: response) { status, response in
                print("Repair Cost API Response: \(String(describing: response))")
            }
        }

        private func makeJsonOfResponse(jsonObject: [String: Any]?) -> [String: Any] {
            return [
                "scan_id": scanID,
                "repaircost": jsonObject ?? [:]
            ]
        }
    

    

    //MARK  This Function to update the Firmware
    // NOTE  This function  only call after the OBD connected successfully  and any type of scan not run
    func updateFirm(completion: @escaping (String) -> Void) {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
            var result = self.rc.getNewestAvailableFirmwareVersion()
             var currnt = ""
         
            do{
                currnt = try result.get() ?? ""
            }catch{
                
            }
            
            self.rc.startDeviceFirmwareUpdate(to:currnt,reqReleaseLevel: .production) { versionInDouble in
                completion("\(versionInDouble)")
            } completionCallback: { error in
                completion("Error")
            }
        }
    }
   
    
    func stopFirmware(){
        self.rc.stopDeviceFirmwareUpdate()
    }
    
    private func postOBDData(completion: @escaping (Bool, String?) -> Void) {

        guard let url = URL(string: Constants.BASE_URL+"update") else {
            print("Invalid URL")
            completion(false, "Invalid URL")
            return
        }
        
        // MARK: 🔹 Create Rediness Array
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
        
        // MARK: 🔹 Create Code Reset Dictionary
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
        
        
        // MARK: 🔹 Create Recall Array
        var recallHis: [[String: Any]] = []
        
        if let recallResponse = recallResponse {
            recallResponse.results.forEach { recall in
                var item: [String: Any] = [:]
                
                if isAutoRecall {
                    // New VIN-based API
                    item["NHTSACampaignNumber"] = recall.nhtsaCampaignNumber ?? "N/A"
                    item["NHTSAActionNumber"]   = recall.mfgCampaignNumber ?? "N/A"
                    item["ReportReceivedDate"]  = recall.nhtsaRecallDate ?? "N/A"
                    item["Component"]           = recall.componentDescriptionrecall
                    item["Remedy"]              = recall.correctiveSummary ?? "N/A"
                    item["Notes"]               = recall.recallNotes ?? "N/A"
                    item["StopSale"]            = (recall.stopSale?.uppercased() == "YES") ? "YES" : "-"
                    item["Summary"]             = recall.subject ?? recall.defectSummary ?? "N/A"
                    item["Consequence"]         = recall.consequenceSummary ?? "N/A"
                    
                } else {
                    // Old NHTSA API
                    if let actionNumber = recall.actionNumber, !actionNumber.isEmpty {
                        item["NHTSAActionNumber"] = actionNumber
                    }
                    item["NHTSACampaignNumber"] = recall.campaignNumber ?? "N/A"
                    item["ReportReceivedDate"]  = recall.reportReceivedDate ?? "N/A"
                    item["Component"]           = recall.component ?? "N/A"
                    item["Summary"]             = recall.summary ?? "N/A"
                    item["Consequence"]         = recall.consequence ?? "N/A"
                    item["Remedy"]              = recall.remedy ?? "N/A"
                    item["Notes"]               = recall.notes ?? "N/A"
                }
                
                recallHis.append(item)
            }
        }
        
        
        // MARK: 🔹 Build FINAL JSON Body
        let body: [String: Any] = [
            "scan_id": scanID,
            "code_reset": codereset,
            "emmission": redinessArray,
            "recall_history": recallHis
        ]
        

        // Convert to raw JSON data
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            print("Error encoding JSON")
            completion(false, "JSON encoding error")
            return
        }
        
        
        // MARK: 🔹 Create Request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("edf9bc2d74ad74ac924c9bcbc337ef62", forHTTPHeaderField: "access-token")
        request.addValue("a4d01210f164259f3ed2f1072f0819d5", forHTTPHeaderField: "server-key")
        
        
        // MARK: 🔹 Send Request
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


    
    
}
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
struct StreamSample {
    let ecuKey: String
    let valueKey: String
    let title: String
    let ecuName: String
    let unit: String
    let timestamp: Date
    let displayValue: String
}
