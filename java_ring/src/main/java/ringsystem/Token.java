package ringsystem;

public class Token {
    public final int tokenId;
    public final RingType ringId;
    public final long origInput;
    public long currentVal;
    public int remainingHops;
    public final long startTimeNanos;

    public Token(int tokenId, RingType ringId, long origInput, int hops) {
        this.tokenId = tokenId;
        this.ringId = ringId;
        this.origInput = origInput;
        this.currentVal = origInput;
        this.remainingHops = hops;
        this.startTimeNanos = System.nanoTime();
    }
}
