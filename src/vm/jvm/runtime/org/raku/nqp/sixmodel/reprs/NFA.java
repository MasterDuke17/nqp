package org.raku.nqp.sixmodel.reprs;

import java.util.Arrays;
import java.util.Comparator;

import org.raku.nqp.runtime.ThreadContext;
import org.raku.nqp.sixmodel.REPR;
import org.raku.nqp.sixmodel.STable;
import org.raku.nqp.sixmodel.SerializationReader;
import org.raku.nqp.sixmodel.SerializationWriter;
import org.raku.nqp.sixmodel.SixModelObject;
import org.raku.nqp.sixmodel.TypeObject;

public class NFA extends REPR {
    /* NFA constants. */
    public static final int EDGE_FATE             = 0;
    public static final int EDGE_EPSILON          = 1;
    public static final int EDGE_CODEPOINT        = 2;
    public static final int EDGE_CODEPOINT_NEG    = 3;
    public static final int EDGE_CHARCLASS        = 4;
    public static final int EDGE_CHARCLASS_NEG    = 5;
    public static final int EDGE_CHARLIST         = 6;
    public static final int EDGE_CHARLIST_NEG     = 7;
    public static final int EDGE_SUBRULE          = 8;
    public static final int EDGE_CODEPOINT_I      = 9;
    public static final int EDGE_CODEPOINT_I_NEG  = 10;
    public static final int EDGE_GENERIC_VAR      = 11;
    public static final int EDGE_CHARRANGE        = 12;
    public static final int EDGE_CHARRANGE_NEG    = 13;
    public static final int EDGE_CODEPOINT_LL     = 14;
    public static final int EDGE_CODEPOINT_I_LL   = 15;
    public static final int EDGE_CODEPOINT_M      = 16;
    public static final int EDGE_CODEPOINT_M_NEG  = 17;
    public static final int EDGE_CODEPOINT_M_LL   = 18;
    public static final int EDGE_CODEPOINT_IM     = 19;
    public static final int EDGE_CODEPOINT_IM_NEG = 20;
    public static final int EDGE_CODEPOINT_IM_LL  = 21;
    public static final int EDGE_SYNTH_CP_COUNT   = 64;

    @Override
    public SixModelObject type_object_for(ThreadContext tc, SixModelObject HOW) {
        STable st = new STable(this, HOW);
        SixModelObject obj = new TypeObject();
        obj.st = st;
        st.WHAT = obj;
        return st.WHAT;
    }

    @Override
    public SixModelObject allocate(ThreadContext tc, STable st) {
        NFAInstance obj = new NFAInstance();
        obj.st = st;
        return obj;
    }

    @Override
    public SixModelObject deserialize_stub(ThreadContext tc, STable st) {
        NFAInstance stub = new NFAInstance();
        stub.st = st;
        return stub;
    }

    private static class optEdgeComp implements Comparator<NFAStateInfo> {
        private int classify_edge(NFAStateInfo e) {
            switch (e.act) {
            case EDGE_SYNTH_CP_COUNT:
                return 0;
            case EDGE_CODEPOINT:
            case EDGE_CODEPOINT_LL:
                return 1;
            default:
                return 2;
            }
        }

        public int compare(NFAStateInfo a, NFAStateInfo b) {
            int type_a = classify_edge(a);
            int type_b = classify_edge(b);
            if (type_a < type_b)
                return -1;
            if (type_a > type_b)
                return 1;
            if (type_a == 1)
                return a.arg_i < b.arg_i ? -1 :
                       a.arg_i > b.arg_i ?  1 :
                                            0;
            else
                return 0;
        }
    }

    public static void sort_states_and_add_synth_cp_node(ThreadContext tc, NFAInstance body) {
        for (int s = 0; s < body.numStates; s++) {
            int applicable_edges = 0;
            int num_orig_edges = body.states[s].length;
            if (num_orig_edges >= 4) {
                for (int e = 0; e < num_orig_edges; e++) {
                    int act = body.states[s][e].act;
                    if (act == EDGE_CODEPOINT || act == EDGE_CODEPOINT_LL)
                        applicable_edges++;
                }
            }

            if (applicable_edges >= 4) {
                int num_new_edges = num_orig_edges + 1;
                NFAStateInfo[] new_edges = new NFAStateInfo[num_new_edges];
                new_edges[0] = new NFAStateInfo();
                new_edges[0].act = EDGE_SYNTH_CP_COUNT;
                new_edges[0].arg_i = applicable_edges;
                System.arraycopy(body.states[s], 0, new_edges, 1, num_orig_edges);
                Arrays.sort(new_edges, 0, num_new_edges, new optEdgeComp());
                body.states[s] = new_edges;
            }
        }
    }

    @Override
    public void deserialize_finish(ThreadContext tc, STable st,
                                   SerializationReader reader, SixModelObject obj) {
        NFAInstance body = (NFAInstance)obj;

        /* Read fates. */
        body.fates = reader.readRef();

        /* Read number of states. */
        body.numStates = (int)reader.readLong();

        if (body.numStates > 0) {
            /* Read state edge list counts. */
            int[] numStateEdges = new int[body.numStates];
            for (int i = 0; i < body.numStates; i++)
                numStateEdges[i] = (int)reader.readLong();

            /* Read state graph. */
            body.states = new NFAStateInfo[body.numStates][];
            for (int i = 0; i < body.numStates; i++) {
                int edges = numStateEdges[i];
                body.states[i] = new NFAStateInfo[edges];
                for (int j = 0; j < edges; j++) {
                    body.states[i][j] = new NFAStateInfo();
                    body.states[i][j].act = (int)reader.readLong();
                    body.states[i][j].to = (int)reader.readLong();
                    switch (body.states[i][j].act & 0xff) {
                    case EDGE_FATE:
                    case EDGE_CODEPOINT_LL:
                    case EDGE_CODEPOINT:
                    case EDGE_CODEPOINT_NEG:
                    case EDGE_CHARCLASS:
                    case EDGE_CHARCLASS_NEG:
                        body.states[i][j].arg_i = (int)reader.readLong();
                        break;
                    case EDGE_CHARLIST:
                    case EDGE_CHARLIST_NEG:
                        body.states[i][j].arg_s = reader.readStr();
                        break;
                    case EDGE_CODEPOINT_I_LL:
                    case EDGE_CODEPOINT_I:
                    case EDGE_CODEPOINT_I_NEG:
                    case EDGE_CHARRANGE:
                    case EDGE_CHARRANGE_NEG: {
                        body.states[i][j].arg_lc = (char)reader.readLong();
                        body.states[i][j].arg_uc = (char)reader.readLong();
                        break;
                    }
                    }
                }
            }
        }

        sort_states_and_add_synth_cp_node(tc, body);
    }

    @Override
    public void serialize(ThreadContext tc, SerializationWriter writer, SixModelObject obj) {
        NFAInstance body = (NFAInstance)obj;

        /* Write fates. */
        writer.writeRef(body.fates);

        /* Write number of states. */
        writer.writeInt(body.numStates);

        /* Write state edge list counts. */
        for (int i = 0; i < body.numStates; i++)
            writer.writeInt(body.states[i].length);

        /* Write state graph. */
        for (int i = 0; i < body.numStates; i++) {
            for (int j = 0; j < body.states[i].length; j++) {
                int act = body.states[i][j].act;
                if (act == EDGE_SYNTH_CP_COUNT)
                    continue;
                writer.writeInt(act);
                writer.writeInt(body.states[i][j].to);
                switch (act & 0xff) {
                case EDGE_FATE:
                case EDGE_CODEPOINT_LL:
                case EDGE_CODEPOINT:
                case EDGE_CODEPOINT_NEG:
                case EDGE_CHARCLASS:
                case EDGE_CHARCLASS_NEG:
                    writer.writeInt(body.states[i][j].arg_i);
                    break;
                case EDGE_CHARLIST:
                case EDGE_CHARLIST_NEG:
                    writer.writeStr(body.states[i][j].arg_s);
                    break;
                case EDGE_CODEPOINT_I_LL:
                case EDGE_CODEPOINT_I:
                case EDGE_CODEPOINT_I_NEG:
                case EDGE_CHARRANGE:
                case EDGE_CHARRANGE_NEG: {
                    writer.writeInt(body.states[i][j].arg_lc);
                    writer.writeInt(body.states[i][j].arg_uc);
                    break;
                }
                }
            }
        }
    }
}
