//===---------------------------------------------------------------------===//
// CPU6 Device Definitions
//===---------------------------------------------------------------------===//

// This is required, LLVM needs at least one subtarget for a target or it will explode
class FeatureSet<string name, string desc, list<SubtargetFeature> i>
    : SubtargetFeature<name, "m_FeatureSetDummy", "true", desc, i>;

def FeatureCPU6 : SubtargetFeature<"CPU6", "m_isCPU6", "true", "This is the only cpu6 subtarget">;

// We also need this
class Device<string Name, list<SubtargetFeature> ExtraFeatures = []>
    : Processor<Name, NoItineraries, ExtraFeatures>;

def : Device<"CPU6", [FeatureCPU6]>;