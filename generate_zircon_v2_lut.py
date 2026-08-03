import math

def zircon_inverse(y):
    # The math inverse of y = log10(40x + 1) / log10(41)
    # x = (41^y - 1) / 40
    val = (math.pow(41.0, y) - 1.0) / 40.0
    return max(0.0, min(1.0, val))

NEW_SIZE = 33
with open('ZIRCON_LOG_V2_TO_REC709.cube', 'w') as f:
    f.write('TITLE "Zircon Log V2 to Rec.709 Linearization"\n')
    f.write(f'LUT_3D_SIZE {NEW_SIZE}\n\n')
    
    for b in range(NEW_SIZE):
        for g in range(NEW_SIZE):
            for r in range(NEW_SIZE):
                rz = r / (NEW_SIZE - 1)
                gz = g / (NEW_SIZE - 1)
                bz = b / (NEW_SIZE - 1)
                
                out_r = zircon_inverse(rz)
                out_g = zircon_inverse(gz)
                out_b = zircon_inverse(bz)
                
                f.write(f"{out_r:.6f} {out_g:.6f} {out_b:.6f}\n")

print("ZIRCON_LOG_V2_TO_REC709.cube generated!")
