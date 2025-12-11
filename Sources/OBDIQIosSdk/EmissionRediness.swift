//
//  EmissionRediness.swift
//  OBDIQIosSdk
//
//  Created by Arvind Mehta on 25/02/25.
//

import Foundation

public class EmissionRediness : @unchecked Sendable {
    var name:String = ""
    var available = false
    var complete = false
    var des:String = ""
    
    init(name: String,available:Bool,status:Bool,desc:String) {
        self.name = name
        self.available = available
        self.complete = status
        self.des = desc
    }
}
