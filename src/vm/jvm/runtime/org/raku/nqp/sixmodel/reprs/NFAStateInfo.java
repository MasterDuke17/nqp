package org.raku.nqp.sixmodel.reprs;

public class NFAStateInfo {
    public int act;
    public int to;
    public int arg_i;
    public String arg_s;
    public char arg_uc;
    public char arg_lc;
    public int getArg() {
        return arg_i;
    }
}
