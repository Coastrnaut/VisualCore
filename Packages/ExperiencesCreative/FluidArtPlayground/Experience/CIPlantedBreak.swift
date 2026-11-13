// CIPlantedBreak.swift — UA-F10 T-U10-006 acceptance only: a Release-only compile error (FrameChecks exists only in
// debug and automation builds). This file is reverted by the next commit.
import VisualCoreExperience

enum CIPlantedBreak {
    static let probe = FrameChecks.minimumLumaSpread
}
