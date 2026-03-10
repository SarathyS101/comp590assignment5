package ringsystem;

public enum RingType {
    NEG, ZERO, POS_EVEN, POS_ODD;

    public static RingType classify(long x) {
        if (x < 0) return NEG;
        if (x == 0) return ZERO;
        if (x % 2 == 0) return POS_EVEN;
        return POS_ODD;
    }
}
