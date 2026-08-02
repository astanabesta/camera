import re
with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    text = f.read()

print("Check 1:", "setDynamicRangeProfile(DynamicRangeProfiles.HLG10)" in text)
print("Check 2:", "HEVCProfileMain10" in text)
