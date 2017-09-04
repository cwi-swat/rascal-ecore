package lang.ecore;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.TypeReifier;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeStore;

public class IO {
	private IValueFactory vf;
	private TypeReifier tr;
	
	public IO(IValueFactory vf){
		this.vf = vf;
		this.tr = new TypeReifier(vf);
	}
	
	public IValue load(IValue reifiedType, ISourceLocation loc, IEvaluatorContext ctx) {
		TypeStore ts = new TypeStore();
		Type rt = tr.valueToType((IConstructor)reifiedType, ts);
		for (Type t: ts.lookupConstructor(rt, "foo")) {
			return vf.constructor(t);
		}
		return null;
	}
	
	
}
