package lang.ecore;

import org.rascalmpl.interpreter.TypeReifier;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;

public class IO {
	private IValueFactory vf;
	private TypeReifier tr;
	private TypeFactory tf;
	
	public IO(IValueFactory vf){
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		this.tf = TypeFactory.getInstance();
	}
	
	public IValue load(IValue reifiedType, ISourceLocation loc) {
		TypeStore ts = new TypeStore();
		Type rt = tr.valueToType((IConstructor)reifiedType, ts);
		Type t = ts.lookupConstructor(rt, "foo", tf.tupleEmpty());
		return vf.constructor(t);
	}
	
	
}
