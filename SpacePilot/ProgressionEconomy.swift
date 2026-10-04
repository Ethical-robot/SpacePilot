import Foundation

/// Survivor-first growth: energy, fuel, Mon, modules, recipes, Relics.
enum ProgressionEconomy {
    /// Base organic energy capacity before storage expansions.
    static let baseOrganicEnergyCapacity: Float = 100
    static let maxShipFuel: Float = 100
    /// Legacy alias — prefer `organicEnergyCapacity(expansions:)`.
    static let maxOrganicEnergy: Float = baseOrganicEnergyCapacity
    static let energyCapacityBonusPerExpansion: Float = 50
    static let maxEnergyStorageExpansions = 5
    static let navModulePriceMon = 120
    static let relicSellPriceMon = 400
    static let scannedYieldMultiplier: Float = 1.33
    static let relicKeyDropChance: Float = 0.08
    static let relicSpawnChancePerTile: Float = 0.12

    /// Cruise fuel burn per second at full throttle (Survivor).
    static let cruiseFuelPerSecond: Float = 0.35
    static let boostFuelPerSecond: Float = 4.5
    static let hyperFuelPerSecond: Float = 8.0

    // Tool energy costs ( Survivor baseline = 1/4 of the original rates ).
    static let analyzerEnergyCost: Float = 1
    static let crumblerEnergyPerSecond: Float = 1.5
    static let launcherEnergyCost: Float = 0.75
    static let slicerEnergyCost: Float = 0.5
    /// Axe is the bootstrap tool — free to swing.
    static let axeEnergyCost: Float = 0

    /// Logs → energy at the ship converter.
    static let energyPerLog: Float = 8

    static func organicEnergyCapacity(expansions: Int) -> Float {
        baseOrganicEnergyCapacity
            + Float(max(0, min(expansions, maxEnergyStorageExpansions)))
                * energyCapacityBonusPerExpansion
    }

    static let navModuleID = "module.nav_autoflight"
    static let roverRefineryModuleID = "module.rover_refinery"
    static let axeBlueprintID = "blueprint.axe"
    static let crumblerBlueprintID = "blueprint.matter_crumbler"
    static let analyzerBlueprintID = "blueprint.analyzer"

    enum ShopSKU: String, CaseIterable, Identifiable, Sendable {
        case navModule
        case unlockAnalyzer
        case unlockCrumbler
        case unlockSlicer
        case upgradeCrumblerEfficiency
        case roverRefinery

        var id: String { rawValue }

        var title: String {
            switch self {
            case .navModule: "Auto-Flight Nav Module"
            case .unlockAnalyzer: "Analyzer Module"
            case .unlockCrumbler: "Matter Crumbler Module"
            case .unlockSlicer: "Sonic Slicer Module"
            case .upgradeCrumblerEfficiency: "Crumbler Efficiency +1"
            case .roverRefinery: "Rover Refinery Module"
            }
        }

        var priceMon: Int {
            switch self {
            case .navModule: navModulePriceMon
            case .unlockAnalyzer: 80
            case .unlockCrumbler: 95
            case .unlockSlicer: 70
            case .upgradeCrumblerEfficiency: 150
            case .roverRefinery: 175
            }
        }

        var detail: String {
            switch self {
            case .navModule:
                "Unlocks DETECT direct-to-nearest autopilot targeting."
            case .unlockAnalyzer:
                "Unlocks the Analyzer tool (uses organic energy)."
            case .unlockCrumbler:
                "Unlocks Matter Crumbler (uses organic energy)."
            case .unlockSlicer:
                "Unlocks Sonic Slicer (uses organic energy)."
            case .upgradeCrumblerEfficiency:
                "Lowers crumbler energy drain by 25% per tier (max 2)."
            case .roverRefinery:
                "Use the ship refinery / fabricator while driving the rover."
            }
        }
    }

    struct CraftRecipe: Identifiable, Sendable {
        let id: String
        let title: String
        let blueprintID: String?
        /// Element display name → count.
        let elements: [String: Int]
        /// Raw inventory costs (any mineral counts as “crystal”).
        let logCost: Int
        let anyMineralCost: Int
        let unlocksTool: SurfaceTool?
        let grantsModuleID: String?
        let grantsBlueprintID: String?
        /// Crafts a single-use energy cube with this recharge amount.
        let energyCubeRecharge: Float?
        /// Permanent capacity bonus granted once (storage expansion).
        let energyCapacityBonus: Float?
        /// Required current expansion count before this storage recipe unlocks.
        let requiredStorageExpansions: Int?

        init(
            id: String,
            title: String,
            blueprintID: String? = nil,
            elements: [String: Int] = [:],
            logCost: Int = 0,
            anyMineralCost: Int = 0,
            unlocksTool: SurfaceTool? = nil,
            grantsModuleID: String? = nil,
            grantsBlueprintID: String? = nil,
            energyCubeRecharge: Float? = nil,
            energyCapacityBonus: Float? = nil,
            requiredStorageExpansions: Int? = nil
        ) {
            self.id = id
            self.title = title
            self.blueprintID = blueprintID
            self.elements = elements
            self.logCost = logCost
            self.anyMineralCost = anyMineralCost
            self.unlocksTool = unlocksTool
            self.grantsModuleID = grantsModuleID
            self.grantsBlueprintID = grantsBlueprintID
            self.energyCubeRecharge = energyCubeRecharge
            self.energyCapacityBonus = energyCapacityBonus
            self.requiredStorageExpansions = requiredStorageExpansions
        }
    }

    static let craftRecipes: [CraftRecipe] = [
        CraftRecipe(
            id: "craft.axe",
            title: "Axe",
            elements: ["Carbon": 2, "Iron": 1],
            unlocksTool: .axe
        ),
        CraftRecipe(
            id: "craft.analyzer",
            title: "Analyzer",
            blueprintID: analyzerBlueprintID,
            elements: ["Silicon": 3, "Copper": 2, "Carbon": 1],
            unlocksTool: .analyzer
        ),
        CraftRecipe(
            id: "craft.crumbler",
            title: "Matter Crumbler",
            blueprintID: crumblerBlueprintID,
            elements: ["Iron": 4, "Titanium": 2, "Silicon": 2],
            unlocksTool: .matterCrumbler
        ),
        CraftRecipe(
            id: "craft.nav",
            title: "Auto-Flight Nav Module",
            elements: [
                "Silicon": 6,
                "Copper": 4,
                "Gold": 2,
                "Titanium": 2
            ],
            grantsModuleID: navModuleID
        ),
        CraftRecipe(
            id: "craft.upgrade.crumbler",
            title: "Crumbler Efficiency Module",
            elements: ["Titanium": 3, "Gold": 1],
            grantsModuleID: "module.crumbler_efficiency"
        ),
        CraftRecipe(
            id: "craft.rover_refinery",
            title: "Rover Refinery Module",
            elements: ["Iron": 3, "Copper": 2, "Silicon": 2],
            grantsModuleID: roverRefineryModuleID
        ),
        // Energy cubes — single-use full/partial recharges.
        CraftRecipe(
            id: "craft.energy_cube.1",
            title: "Energy Cube I (100)",
            logCost: 10,
            anyMineralCost: 10,
            energyCubeRecharge: 100
        ),
        CraftRecipe(
            id: "craft.energy_cube.2",
            title: "Energy Cube II (150)",
            elements: ["Carbon": 4],
            logCost: 15,
            anyMineralCost: 20,
            energyCubeRecharge: 150
        ),
        CraftRecipe(
            id: "craft.energy_cube.3",
            title: "Energy Cube III (200)",
            elements: ["Carbon": 6, "Silicon": 4],
            logCost: 20,
            anyMineralCost: 30,
            energyCubeRecharge: 200
        ),
        // Permanent storage expansions — each tier needs one more element type.
        CraftRecipe(
            id: "craft.energy_storage.1",
            title: "Energy Storage +50",
            elements: ["Iron": 3, "Silicon": 3],
            energyCapacityBonus: energyCapacityBonusPerExpansion,
            requiredStorageExpansions: 0
        ),
        CraftRecipe(
            id: "craft.energy_storage.2",
            title: "Energy Storage +50 (II)",
            elements: ["Iron": 3, "Silicon": 3, "Copper": 3],
            energyCapacityBonus: energyCapacityBonusPerExpansion,
            requiredStorageExpansions: 1
        ),
        CraftRecipe(
            id: "craft.energy_storage.3",
            title: "Energy Storage +50 (III)",
            elements: ["Iron": 3, "Silicon": 3, "Copper": 3, "Gold": 2],
            energyCapacityBonus: energyCapacityBonusPerExpansion,
            requiredStorageExpansions: 2
        ),
        CraftRecipe(
            id: "craft.energy_storage.4",
            title: "Energy Storage +50 (IV)",
            elements: [
                "Iron": 3,
                "Silicon": 3,
                "Copper": 3,
                "Gold": 2,
                "Titanium": 2
            ],
            energyCapacityBonus: energyCapacityBonusPerExpansion,
            requiredStorageExpansions: 3
        ),
        CraftRecipe(
            id: "craft.energy_storage.5",
            title: "Energy Storage +50 (V)",
            elements: [
                "Iron": 3,
                "Silicon": 3,
                "Copper": 3,
                "Gold": 2,
                "Titanium": 2,
                "Carbon": 4
            ],
            energyCapacityBonus: energyCapacityBonusPerExpansion,
            requiredStorageExpansions: 4
        )
    ]

    /// Rough refine table: material category → element yields.
    static func refineYield(
        materialName: String,
        category: SurfacePickup.Category
    ) -> [(element: String, count: Int)] {
        switch category {
        case .log:
            return [("Carbon", 2), ("Hydrogen", 1)]
        case .mineral:
            let lower = materialName.lowercased()
            if lower.contains("relic") {
                return [("Titanium", 3), ("Gold", 2), ("Silicon", 2)]
            }
            if lower.contains("iron") || lower.contains("basalt") {
                return [("Iron", 3), ("Carbon", 1)]
            }
            if lower.contains("crystal") || lower.contains("ice") {
                return [("Silicon", 2), ("Hydrogen", 2)]
            }
            return [("Iron", 1), ("Silicon", 1), ("Carbon", 1)]
        case .electronic:
            return [("Copper", 2), ("Silicon", 2), ("Gold", 1)]
        case .creatureMaterial:
            return [("Carbon", 2), ("Nitrogen", 1)]
        case .relic:
            return [("Titanium", 4), ("Gold", 3), ("Dark Residue", 1)]
        case .relicKey, .element, .blueprint, .module:
            return []
        }
    }

    static func formatMon(_ amount: Int) -> String {
        "§\(amount)"
    }

    static func energyCostMultiplier(
        difficulty: GameDifficulty
    ) -> Float {
        switch difficulty {
        case .survivor: 1
        case .normal: 0.35
        case .creative: 0
        }
    }

    static func fuelCostMultiplier(
        difficulty: GameDifficulty
    ) -> Float {
        switch difficulty {
        case .survivor: 1
        case .normal: 0.4
        case .creative: 0
        }
    }
}

struct ProgressionSnapshot: Codable, Sendable {
    var organicEnergy: Float
    var shipFuel: Float
    var hasNavModule: Bool
    var ownedModuleIDs: [String]
    var ownedBlueprintIDs: [String]
    var crumblerEfficiencyTier: Int
    var toolUpgradeTiers: [String: Int]
    var guaranteedAxeGranted: Bool
    /// Completed permanent energy-capacity expansion crafts (0...5).
    var energyStorageExpansions: Int?

    enum CodingKeys: String, CodingKey {
        case organicEnergy, shipFuel, hasNavModule, ownedModuleIDs
        case ownedBlueprintIDs, crumblerEfficiencyTier, toolUpgradeTiers
        case guaranteedAxeGranted, energyStorageExpansions
    }
}

enum RelicOpenReward: Sendable {
    case elements([(String, Int)])
    case blueprint(String)
    case module(String)
}
