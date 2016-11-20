package org.perl6.nqp.jast2bc;

import org.objectweb.asm.Attribute;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.ByteVector;
import org.objectweb.asm.Label;

public class SourceFilenameAttribute extends Attribute {
    public String file;

    public SourceFilenameAttribute(String f) {
        super(f);
        this.file = f;
    }

    public String getFile() {
        return file;
    }

    @Override
    public boolean isUnknown() {
        return false;
    }

    @Override
    public boolean isCodeAttribute() {
        return false;
    }

    @Override
    protected Attribute read(ClassReader cr, int off, int len, char[] buf, int codeOff, Label[] labels) {
        return new SourceFilenameAttribute(cr.readUTF8(off, buf));
    }

    @Override
    protected ByteVector write(ClassWriter cw, byte[] code, int len, int maxStack, int maxLocals) {
        return new ByteVector().putShort(cw.newUTF8(file));
    }
}
