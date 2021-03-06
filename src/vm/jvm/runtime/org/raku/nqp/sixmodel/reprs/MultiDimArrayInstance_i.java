package org.raku.nqp.sixmodel.reprs;

import org.raku.nqp.runtime.ThreadContext;
import org.raku.nqp.sixmodel.SerializationReader;
import org.raku.nqp.sixmodel.SerializationWriter;
import org.raku.nqp.sixmodel.SixModelObject;

public class MultiDimArrayInstance_i extends MultiDimArrayInstanceBase {
    public long[] slots;

    @Override
    public void set_dimensions(ThreadContext tc, long[] dims) {
        super.set_dimensions(tc, dims);
        if (slots == null)
            slots = new long[numSlots()];
        else
            duplicateSetDimensions(tc);
    }

    @Override
    public void at_pos_multidim_native(ThreadContext tc, long[] indices) {
        tc.native_type = ThreadContext.NATIVE_INT;
        tc.native_i = slots[indicesToFlatIndex(tc, indices)];
    }

    @Override
    public void bind_pos_multidim_native(ThreadContext tc, long[] indices) {
        tc.native_type = ThreadContext.NATIVE_INT;
        slots[indicesToFlatIndex(tc, indices)] = tc.native_i;
    }

    public SixModelObject clone(ThreadContext tc) {
        try {
            MultiDimArrayInstance_i clone = (MultiDimArrayInstance_i)this.clone();
            clone.sc = null;
            clone.dimensions = this.dimensions.clone();
            if (this.slots != null)
                clone.slots = this.slots.clone();
            return clone;
        } catch (CloneNotSupportedException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void serializeValues(ThreadContext tc, SerializationWriter writer) {
        for (int i = 0; i < slots.length; i++)
            writer.writeInt(slots[i]);
    }

    @Override
    public void deserializeValues(ThreadContext tc, SerializationReader reader) {
        slots = new long[numSlots()];
        for (int i = 0; i < slots.length; i++)
            slots[i] = reader.readLong();
    }
}
