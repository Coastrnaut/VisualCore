// ElementsTests — feature 110 (A15-P01) T-A15-102 (FR-A15-101; clarification Q1; SC-A15-101). The element catalog,
// host-free and short: the ten elements H, C, N, O, F, P, S, Cl, Br, I in atomic-number order with the exact clarified
// names, atomic numbers, covalent radii, van der Waals radii and colours; one source record per stored value (50) with
// PubChem (public domain) for every quantity but the covalent radius (Cordero et al. 2008, factual data); symbols match
// case-insensitively and come back normalised.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct ElementsTests {
    @Test func theTenElementsHaveTheClarifiedValuesInAtomicNumberOrder() {
        let symbols: [String] = ["H", "C", "N", "O", "F", "P", "S", "Cl", "Br", "I"]
        let names: [String] = ["Hydrogen", "Carbon", "Nitrogen", "Oxygen", "Fluorine", "Phosphorus", "Sulfur",
                               "Chlorine", "Bromine", "Iodine"]
        let numbers: [Int] = [1, 6, 7, 8, 9, 15, 16, 17, 35, 53]
        let covalent: [Double] = [0.31, 0.76, 0.71, 0.66, 0.57, 1.07, 1.05, 1.02, 1.20, 1.39]
        let vanDerWaals: [Double] = [1.20, 1.70, 1.55, 1.52, 1.35, 1.80, 1.80, 1.75, 1.83, 1.98]
        let colors: [String] = ["FFFFFF", "909090", "3050F8", "FF0D0D", "90E050", "FF8000", "FFFF30", "1FF01F",
                                "A62929", "940094"]
        let all = Elements.all
        #expect(all.count == 10)
        for index in 0..<min(all.count, 10) {
            let element = all[index]
            #expect(element.symbol == symbols[index])
            #expect(element.name == names[index], "\(element.symbol)")
            #expect(element.atomicNumber == numbers[index], "\(element.symbol)")
            #expect(element.covalentRadius == covalent[index], "\(element.symbol)")
            #expect(element.vanDerWaalsRadius == vanDerWaals[index], "\(element.symbol)")
            #expect(element.colorHex == colors[index], "\(element.symbol)")
        }
        let sortedNumbers: [Int] = all.map(\.atomicNumber).sorted()
        #expect(all.map(\.atomicNumber) == sortedNumbers)
    }

    @Test func everyStoredValueHasOneSourceRecord() {
        let sources = Elements.sources
        #expect(sources.count == 50)
        #expect(ElementQuantity.allCases.map(\.rawValue)
                == ["name", "atomic-number", "covalent-radius", "van-der-waals-radius", "color"])
        for element in Elements.all {
            for quantity in ElementQuantity.allCases {
                let matching = sources.filter { $0.key == element.symbol && $0.quantity == quantity.rawValue }
                #expect(matching.count == 1, "\(element.symbol) \(quantity.rawValue)")
                #expect(Elements.source(symbol: element.symbol, quantity: quantity) == matching.first)
            }
        }
        for record in sources {
            if record.quantity == "covalent-radius" {
                #expect(record.title == "Covalent radii revisited (B. Cordero et al., Dalton Transactions, 2008)")
                #expect(record.publisher == "Royal Society of Chemistry")
                #expect(record.license == "factual-data" && record.units == "Å")
            } else {
                #expect(record.title == "PubChem Periodic Table of Elements", "\(record.key) \(record.quantity)")
                #expect(record.publisher == "National Library of Medicine (NCBI)")
                #expect(record.link == "pubchem.ncbi.nlm.nih.gov/periodic-table")
                #expect(record.license == "public-domain")
                #expect(record.units == (record.quantity == "van-der-waals-radius" ? "Å" : ""))
            }
        }
    }

    @Test func symbolsMatchIgnoringCaseAndComeBackNormalised() {
        #expect(Elements.element(symbol: "cl")?.symbol == "Cl")
        #expect(Elements.element(symbol: "CL")?.name == "Chlorine")
        #expect(Elements.element(symbol: "bR")?.atomicNumber == 35)
        #expect(Elements.element(symbol: "h")?.symbol == "H")
        for element in Elements.all {
            #expect(Elements.element(symbol: element.symbol) == element)
            #expect(Elements.element(symbol: element.symbol.lowercased()) == element)
        }
        let unknown: [String] = ["", "He", "Xx", "Na", "c l", "1", "Fe"]
        for symbol in unknown {
            #expect(Elements.element(symbol: symbol) == nil, "\(symbol)")
        }
    }
}
