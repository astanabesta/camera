import math

def zircon_v3_inverse(y):
    # Inverse of y = log10(x * 100 + 1) / log10(101)
    # x = (101^y - 1) / 100
    val = (math.pow(101.0, y) - 1.0) / 100.0
    return max(0.0, min(1.0, val))

NEW_SIZE = 33
with open('ZIRCON_LOG_V3_MAX_DR.cube', 'w') as f:
    f.write('TITLE "Zircon Log V3 to Rec.709 Linearization"\n')
    f.write(f'LUT_3D_SIZE {NEW_SIZE}\n\n')
    
    for b in range(NEW_SIZE):
        for g in range(NEW_SIZE):
            for r in range(NEW_SIZE):
                rz = r / (NEW_SIZE - 1)
                gz = g / (NEW_SIZE - 1)
                bz = b / (NEW_SIZE - 1)
                
                out_r = zircon_v3_inverse(rz)
                out_g = zircon_v3_inverse(gz)
                out_b = zircon_v3_inverse(bz)
                
                f.write(f"{out_r:.6f} {out_g:.6f} {out_b:.6f}\n")

print("ZIRCON_LOG_V3_MAX_DR.cube generated!")
