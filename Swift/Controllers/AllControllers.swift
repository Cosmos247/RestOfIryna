//
//  AllControllers.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import Lingo
import SwiftTelegramBot

struct Controllers {
    // MARK: - Controllers initialization.
    static let registration          = Registration         (routerName: "registration")
    static let mainController        = MainController       (routerName: "main" )
    static let settingsController    = SettingsController   (routerName: "settings")
    static let explorationController = ExplorationController(routerName: "exploration")
    static let combatController      = CombatController     (routerName: "combat")
    static let estateController      = EstateController     (routerName: "estate")
    static let capitalController     = CapitalController    (routerName: "capital")
    static let inventoryController   = InventoryController  (routerName: "inventory")

    static let all: [TGControllerBase] = [
        registration,
        mainController,
        settingsController,
        explorationController,
        combatController,
        estateController,
        capitalController,
        inventoryController
    ]
    
    static func attachAllHandlers(for bot: TGBot, lingo: Lingo) async {
        for controller in all {
            await controller.attachHandlers(to: bot, lingo: lingo)
        }
    }
}
