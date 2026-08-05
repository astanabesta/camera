package ai.arena.zirconcinema.recording;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.AudioTimestamp;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaRecorder;
import android.os.SystemClock;
import android.util.Log;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.BooleanSupplier;

/**
 * Wraps AudioRecord + MediaCodec for AAC audio encoding.
 * 
 * Phase 1: Basic audio capture and encoding with proper timestamps.
 */
public class AudioEncoderWrapper {
    private static final String TAG = "AudioEncoderWrapper";
    
    private static final int SAMPLE_RATE = 48000;
    private static final int CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_STEREO;
    private static final int AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;
    private static final int BIT_RATE = 192000; // 192 kbps AAC
    
    private AudioRecord audioRecord;
    private MediaCodec audioEncoder;
    private MediaCodec.BufferInfo outputBufferInfo;
    
    /**
     * Optional gate that delays the first audio read until the video track
     * has been added to the muxer, so the initial AAC chunks are not encoded
     * only to be dropped while the container cannot take samples yet.
     */
    private BooleanSupplier startGate;
    private static final long START_GATE_TIMEOUT_MS = 2000;
    
    private Thread audioInputThread;
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    private final AtomicInteger samplesCaptured = new AtomicInteger(0);
    private final AtomicInteger audioChunksEncoded = new AtomicInteger(0);
    
    private final TimestampManager timestampManager;
    
    public AudioEncoderWrapper(TimestampManager timestampManager) {
        this.timestampManager = timestampManager;
        Log.i(TAG, "Audio encoder wrapper created");
    }
    
    /**
     * Set a gate that is polled before the first AudioRecord read.
     * While the gate returns false the input thread waits (the HAL buffer
     * keeps filling), so early audio is not encoded only to be dropped
     * because the muxer has no tracks yet.
     */
    public void setStartGate(BooleanSupplier gate) {
        this.startGate = gate;
    }
    
    /**
     * Configure and start audio recording + encoding.
     * 
     * @throws IOException if setup fails
     */
    public void start() throws IOException {
        if (isRunning.get()) {
            throw new IllegalStateException("Audio encoder already started");
        }
        
        // Create AudioRecord
        int bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT);
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            throw new IOException("Invalid audio buffer size");
        }
        
        audioRecord = new AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.MIC)
                .setAudioFormat(new AudioFormat.Builder()
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(CHANNEL_CONFIG)
                        .setEncoding(AUDIO_FORMAT)
                        .build())
                .setBufferSizeInBytes(bufferSize * 4) // Extra headroom for the start gate
                .build();
        
        if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
            throw new IOException("AudioRecord initialization failed");
        }
        
        // Create AAC encoder
        MediaFormat audioFormat = new MediaFormat();
        audioFormat.setString(MediaFormat.KEY_MIME, "audio/mp4a-latm");
        audioFormat.setInteger(MediaFormat.KEY_SAMPLE_RATE, SAMPLE_RATE);
        audioFormat.setInteger(MediaFormat.KEY_CHANNEL_COUNT, 2);
        audioFormat.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE);
        audioFormat.setInteger(MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC);
        
        Log.i(TAG, "Creating AAC encoder with format: " + audioFormat);
        
        audioEncoder = MediaCodec.createEncoderByType("audio/mp4a-latm");
        audioEncoder.configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        audioEncoder.start();
        
        outputBufferInfo = new MediaCodec.BufferInfo();
        
        // Start recording
        audioRecord.startRecording();
        isRunning.set(true);
        
        // Start audio input thread
        audioInputThread = new Thread(this::audioInputLoop, "AudioInputThread");
        audioInputThread.start();
        
        Log.i(TAG, "Audio encoder started successfully");
    }
    
    /**
     * Audio input loop - reads from AudioRecord and feeds to encoder.
     */
    private void audioInputLoop() {
        Log.i(TAG, "Audio input thread started");
        
        // Wait for the muxer before the first read so that the encoded lead-in
        // audio is actually written instead of dropped by the muxer guard.
        if (startGate != null) {
            long gateStart = SystemClock.uptimeMillis();
            while (isRunning.get() && !startGate.getAsBoolean()) {
                if (SystemClock.uptimeMillis() - gateStart > START_GATE_TIMEOUT_MS) {
                    Log.w(TAG, "Start gate timed out after " + START_GATE_TIMEOUT_MS +
                          " ms; capturing without muxer ready");
                    break;
                }
                try {
                    Thread.sleep(5);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
        
        // AAC frame is 1024 samples per channel
        int frameSize = 1024 * 2 * 2; // 1024 frames * 2 channels * 2 bytes per sample (PCM16)
        byte[] audioBuffer = new byte[frameSize];
        
        // Hardware-clock anchor. AudioTimestamp.nanoTime is the CLOCK_BOOTTIME
        // instant at which frame framePosition was captured — the same clock
        // domain as the camera sensor timestamps, so the two tracks can be
        // aligned by the TimestampManager.
        final AudioTimestamp anchor = new AudioTimestamp();
        long anchorNanoTime = -1;
        long anchorFramePosition = -1;
        
        while (isRunning.get()) {
            int bytesRead = audioRecord.read(audioBuffer, 0, frameSize);
            
            if (bytesRead > 0) {
                int framesRead = bytesRead / 4; // 4 bytes per PCM16 stereo frame
                long chunkStartFrame = samplesCaptured.get();
                
                // Refresh the hardware-clock anchor against the just-read
                // position. AudioRecord.getTimestamp() reports when the frame
                // at framePosition entered the stream.
                int status = audioRecord.getTimestamp(anchor, AudioTimestamp.TIMEBASE_BOOTTIME);
                if (status == AudioRecord.SUCCESS) {
                    anchorNanoTime = anchor.nanoTime;
                    anchorFramePosition = anchor.framePosition;
                }
                
                long timestampUs;
                if (anchorNanoTime > 0) {
                    // Interpolate the capture instant of this chunk's FIRST
                    // frame from the anchor. Stamping the whole chunk with
                    // "now" would skew every chunk by the variable buffer
                    // depth inside AudioRecord.
                    long chunkStartNs = anchorNanoTime
                            + ((chunkStartFrame - anchorFramePosition) * 1_000_000_000L) / SAMPLE_RATE;
                    timestampUs = chunkStartNs / 1000; // ns → µs
                } else {
                    // Fallback: no usable hardware anchor yet, estimate from
                    // the running frame count (drifts, but strictly monotonic).
                    timestampUs = (chunkStartFrame * 1_000_000L) / SAMPLE_RATE;
                }
                
                // Register with timestamp manager
                long ptsUs = timestampManager.registerAudioChunk(timestampUs);
                
                // Feed to encoder
                feedEncoder(audioBuffer, bytesRead, ptsUs);
                
                samplesCaptured.addAndGet(framesRead);
                
                int sampleCount = samplesCaptured.get();
                if (sampleCount <= 48000 || sampleCount % 480000 == 0) { // Log first second and every 10 seconds
                    Log.d(TAG, "Audio samples captured: " + sampleCount + 
                          " (" + (sampleCount / SAMPLE_RATE) + " seconds)");
                }
            } else if (bytesRead < 0) {
                Log.e(TAG, "AudioRecord read error: " + bytesRead);
                break;
            }
        }
        
        Log.i(TAG, "Audio input thread stopped");
    }
    
    /**
     * Feed audio data to encoder.
     */
    private void feedEncoder(byte[] data, int size, long presentationTimeUs) {
        if (audioEncoder == null) return;
        
        int inputIndex = audioEncoder.dequeueInputBuffer(10000); // 10ms timeout
        if (inputIndex >= 0) {
            ByteBuffer inputBuffer = audioEncoder.getInputBuffer(inputIndex);
            if (inputBuffer != null) {
                inputBuffer.clear();
                inputBuffer.put(data, 0, size);
                audioEncoder.queueInputBuffer(inputIndex, 0, size, presentationTimeUs, 0);
            }
        } else {
            Log.w(TAG, "Audio encoder input buffer not available");
        }
    }
    
    /**
     * Drain encoded audio output.
     * Call this repeatedly from a dedicated thread.
     * 
     * @param muxer MuxerController to write encoded data
     * @param trackIndex Muxer track index for audio
     * @return true if encoder is still running, false if EOS
     */
    public boolean drainOutput(MuxerController muxer, int trackIndex) {
        if (audioEncoder == null || !isRunning.get()) {
            return false;
        }
        
        int outputIndex = audioEncoder.dequeueOutputBuffer(outputBufferInfo, 10000);
        
        if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            MediaFormat outputFormat = audioEncoder.getOutputFormat();
            Log.i(TAG, "Audio encoder output format changed: " + outputFormat);
            // Muxer will handle this
            return true;
        }
        
        if (outputIndex >= 0) {
            ByteBuffer outputBuffer = audioEncoder.getOutputBuffer(outputIndex);
            
            if (outputBuffer != null && outputBufferInfo.size > 0) {
                muxer.writeSampleData(trackIndex, outputBuffer, outputBufferInfo);
                
                int chunkCount = audioChunksEncoded.incrementAndGet();
                if (chunkCount <= 5 || chunkCount % 100 == 0) {
                    Log.d(TAG, "Audio chunk #" + chunkCount + 
                          " PTS: " + outputBufferInfo.presentationTimeUs + " µs" +
                          " Size: " + outputBufferInfo.size + " bytes");
                }
            }
            
            audioEncoder.releaseOutputBuffer(outputIndex, false);
            
            if ((outputBufferInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                Log.i(TAG, "Audio encoder reached end of stream");
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Stop and release audio resources.
     */
    public void stop() {
        if (!isRunning.get()) return;
        
        Log.i(TAG, "Stopping audio encoder");
        isRunning.set(false);
        
        // Wait for audio input thread
        if (audioInputThread != null) {
            try {
                audioInputThread.join(2000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        
        // Stop AudioRecord
        if (audioRecord != null) {
            audioRecord.stop();
            audioRecord.release();
            audioRecord = null;
        }
        
        // Stop encoder
        if (audioEncoder != null) {
            try {
                audioEncoder.stop();
            } catch (IllegalStateException e) {
                Log.w(TAG, "Audio encoder stop failed: " + e.getMessage());
            }
            audioEncoder.release();
            audioEncoder = null;
        }
        
        Log.i(TAG, "Audio encoder stopped");
    }
    
    /**
     * Get samples captured count.
     */
    public int getSamplesCaptured() {
        return samplesCaptured.get();
    }
    
    /**
     * Get audio chunks encoded count.
     */
    public int getAudioChunksEncoded() {
        return audioChunksEncoded.get();
    }
    
    /**
     * Get encoder output format.
     * Only valid after encoder is started and format has changed.
     */
    public MediaFormat getOutputFormat() {
        if (audioEncoder != null) {
            try {
                return audioEncoder.getOutputFormat();
            } catch (IllegalStateException e) {
                return null;
            }
        }
        return null;
    }
    
    /**
     * Log audio statistics.
     */
    public void logStats() {
        int samples = samplesCaptured.get();
        int chunks = audioChunksEncoded.get();
        
        Log.i(TAG, "Audio encoder stats:");
        Log.i(TAG, "  Samples captured: " + samples + " (" + (samples / SAMPLE_RATE) + " seconds)");
        Log.i(TAG, "  AAC chunks encoded: " + chunks);
    }
}
