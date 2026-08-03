# The MediaCodec hardware encoder on Dimensity 7200-Ultra typically supports a maximum video encoding resolution of 3840x2160 (4K UHD) at 30fps.
# Open Gate resolution (4080x3060) is roughly 12.5 Megapixels.
# 4K UHD (3840x2160) is roughly 8.3 Megapixels.

# The MediaRecorder throws an exception and fails to record if you request a resolution that exceeds the hardware video encoder's maximum macroblock limit.
