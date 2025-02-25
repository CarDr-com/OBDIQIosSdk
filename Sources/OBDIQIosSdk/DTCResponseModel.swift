//
//  File.swift
//  OBDIQPakage
//
//  Created by Arvind Mehta on 21/02/25.
//

import Foundation

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
