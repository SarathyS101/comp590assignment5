package ringsystem;

public class Transforms {
    public static long apply(RingType ring, long v) {
        return switch (ring) {
            case NEG -> v * 3 + 1;
            case ZERO -> v + 7;
            case POS_EVEN -> v * 101;
            case POS_ODD -> v * 101 + 1;
        };
    }
}
