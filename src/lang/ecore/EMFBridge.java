package lang.ecore;

import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.eclipse.core.runtime.Platform;
import org.eclipse.emf.common.command.Command;
import org.eclipse.emf.common.command.CompoundCommand;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EFactory;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.emf.edit.command.AddCommand;
import org.eclipse.emf.edit.command.DeleteCommand;
import org.eclipse.emf.edit.command.RemoveCommand;
import org.eclipse.emf.edit.command.SetCommand;
import org.eclipse.emf.edit.domain.EditingDomain;
import org.rascalmpl.debug.IRascalMonitor;
import org.rascalmpl.eclipse.nature.ProjectEvaluatorFactory;
import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.IEvaluator;
import org.rascalmpl.interpreter.NullRascalMonitor;
import org.rascalmpl.interpreter.TypeReifier;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.result.AbstractFunction;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;
import org.rascalmpl.interpreter.types.RascalTypeFactory;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.values.ValueFactoryFactory;
import org.rascalmpl.values.uptr.RascalValueFactory;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IReal;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;

public class EMFBridge {

	private static TypeFactory tf = TypeFactory.getInstance();
	private static Map<String, Evaluator> bundleEvals = new HashMap<>();

	// The signature of the `function` should be
	// Patch (Loader[&T] load);

	public static CompoundCommand runRascal(String bundleId, EditingDomain domain, EObject obj, String module, String function) {
		if (!(bundleEvals.containsKey(bundleId))) {
			GlobalEnvironment heap = new GlobalEnvironment();
		    Evaluator eval = new Evaluator(ValueFactoryFactory.getValueFactory(), new PrintWriter(System.err), new PrintWriter(System.out), 
		    		new ModuleEnvironment("$emfbridge$", heap), heap);
		    ProjectEvaluatorFactory.getInstance().initializeBundleEvaluator(Platform.getBundle(bundleId), eval);
			bundleEvals.put(bundleId, eval);
		}
		Evaluator eval = bundleEvals.get(bundleId);
		IRascalMonitor mon = new NullRascalMonitor();
		eval.doImport(mon, module);
		ISourceLocation src = eval.getValueFactory().sourceLocation(EcoreUtil.getURI(obj).toString());
		ITuple patch = (ITuple) eval.call(function, new IValue[] { new ObtainModelClosure(obj, src, eval) });
		
		return patch(domain, obj, patch);
	}
	
	@SuppressWarnings("unchecked")
	public static CompoundCommand patch(EditingDomain domain, EObject root, ITuple patch) {
		EPackage pkg = root.eClass().getEPackage();
		EFactory fact = pkg.getEFactoryInstance();
		List<Command> cmds = new ArrayList<>();
		Map<IConstructor, EObject> cache = new HashMap<>();
		
		for (IValue v: (IList)patch.get(1)) {
			ITuple idEdit = (ITuple)v;
			IConstructor id = (IConstructor) idEdit.get(0);
			IConstructor edit = (IConstructor) idEdit.get(1);
			if (edit.getName().equals("create")) {
				// TODO: we actually create the new objects during patch, not while doing the commands...
				String clsName = ((IString)edit.get("class")).getValue();
				EClass eCls = (EClass) pkg.getEClassifier(clsName);
				EObject obj = fact.create(eCls);
				cache.put(id, obj);
			}
			else {
				EObject obj = lookup(root, id, cache);
				String fieldName = ((IString)edit.get("field")).getValue();
				EStructuralFeature field = obj.eClass().getEStructuralFeature(fieldName);

				if (edit.getName().equals("destroy")) {
					cmds.add(DeleteCommand.create(domain, obj));
				}
				else if (edit.getName().equals("put")) {
					Object val = value2obj(edit.get("val"), root, cache);
					cmds.add(SetCommand.create(domain, obj, field, val));
				}
				else if (edit.getName().equals("unset")) {
					cmds.add(SetCommand.create(domain, obj, field, null));
				}
				else {
					List<Object> lst = (List<Object>)obj.eGet(field);
					int pos = ((IInteger)edit.get("pos")).intValue();
					
					if (edit.getName().equals("ins")) {
						cmds.add(AddCommand.create(domain, obj, field, value2obj(edit.get("val"), root, cache), pos));
					}
					else if (edit.getName().equals("del")) {
						cmds.add(RemoveCommand.create(domain, obj, field, lst.get(pos)));
					}
					else {
						throw RuntimeExceptionFactory.illegalArgument(edit, null, null);
					}
				}
			}
		}
		return new CompoundCommand(cmds);
	}
	
	/*
	 *  patch object root according to `patch`.
	 *  fill cache (mapping ids to EObjects) and newIds in the process
	 *  return the new root
	 *  NB: root may be null, when we're creating from scratch.
	 */
	@SuppressWarnings({"unchecked", "unused"})
	private static EObject patch(EPackage pkg, EObject root, ITuple patch, Map<IConstructor, EObject> cache, Set<IConstructor> newIds) {
		EFactory fact = pkg.getEFactoryInstance();
		
		for (IValue v: (IList)patch.get(1)) {
			ITuple idEdit = (ITuple)v;
			IConstructor id = (IConstructor) idEdit.get(0);
			IConstructor edit = (IConstructor) idEdit.get(1);
			if (edit.getName().equals("create")) {
				String clsName = ((IString)edit.get("class")).getValue();
				EClass eCls = (EClass) pkg.getEClassifier(clsName);
				EObject obj = fact.create(eCls);
				cache.put(id, obj);
				newIds.add(id);
			}
			else {
				EObject obj = lookup(root, id, cache);
				String fieldName = ((IString)edit.get("field")).getValue();
				EStructuralFeature field = obj.eClass().getEStructuralFeature(fieldName);

				if (edit.getName().equals("destroy")) {
					// this deletes obj from all containers and references to it
					// but that's ok, because deletes are always at the end. 
					EcoreUtil.delete(obj);
				}
				else if (edit.getName().equals("put")) {
					Object val = value2obj(edit.get("val"), root, cache);
					obj.eSet(field, val);
				}
				else if (edit.getName().equals("unset")) {
					obj.eUnset(field);
				}
				else {
					List<Object> lst = (List<Object>)obj.eGet(field);
					int pos = ((IInteger)edit.get("pos")).intValue();
					
					if (edit.getName().equals("ins")) {
						lst.add(pos, value2obj(edit.get("val"), root, cache));
					}
					else if (edit.getName().equals("del")) {
						lst.remove(pos);
					}
					else {
						throw RuntimeExceptionFactory.illegalArgument(edit, null, null);
					}
				}
			}
		}
		
		return lookup(root, (IConstructor)patch.get(0), cache);
	}

	private static Object value2obj(IValue v, EObject root, Map<IConstructor, EObject> cache) {
		// todo: should check against actual Id type.
		Type type = v.getType();
		if (type.isAbstractData() && ((IConstructor)v).getName().equals("id")) {
			return lookup(root, (IConstructor)v, cache);
		}
		if (type.isInteger()) {
			return ((IInteger)v).intValue();
		}
		if (type.isString()) {
			return ((IString)v).getValue();
		}
		if (type.isReal()) {
			return ((IReal)v).floatValue();
		}
		if (type.isBool()) {
			return ((IBool)v).getValue();
		}
		throw RuntimeExceptionFactory.illegalArgument(v, null, null);
	}
	
	private static EObject lookup(EObject root, IConstructor id, Map<IConstructor, EObject> cache) {
		if (cache.containsKey(id)) {
			return cache.get(id);
		}
		
		// created things always are in the cache, so we can assume
		// loc ids in this case.
		String fragment = ((ISourceLocation)id.get(0)).getFragment();

		// not sure why it has to be this way.
		EObject obj = fragment.equals("/") ? root :  EcoreUtil.getEObject(root, fragment.substring(2));
		
		cache.put(id, obj);
		return obj;
	}
	
	
	private static class ObtainModelClosure extends AbstractFunction {
		
		private EObject model;
		private ISourceLocation src;
		
		private static final FunctionType myType;
		
		static {
			RascalTypeFactory rtf = RascalTypeFactory.getInstance();
			Type param = tf.parameterType("T", tf.nodeType());
			myType = (FunctionType) rtf.functionType(param, tf.tupleType(rtf.reifiedType(param)), tf.tupleEmpty());
		}

		public ObtainModelClosure(EObject model, ISourceLocation src, IEvaluator<Result<IValue>> eval) {
			super(null, eval, myType, Collections.emptyList(), false, eval.getCurrentEnvt());
			this.model = model;
			this.src = src;
		}
		
		@Override
		public ICallableValue cloneInto(Environment env) {
			return null;
		}
		
		@Override
		public boolean isStatic() {
			return false;
		}
		
		@Override
		public boolean isDefault() {
			return false;
		}
		
		@Override
		public IConstructor encodeAsConstructor() {
			IValueFactory vf = eval.getValueFactory();
			return vf.constructor(RascalValueFactory.Function_Function, vf.sourceLocation("file:///unknown"));
		}
		
		@Override
		public Result<IValue> call(IRascalMonitor arg0, Type[] arg1, IValue[] arg2, Map<String, IValue> arg3) {
			return call(arg1, arg2, arg3);
		}
		
		@Override
		public Result<IValue> call(Type[] arg0, IValue[] args, Map<String, IValue> kws) {
			// TODO: cache the reifiedType and type store
			// it will always be the same for every call. 
			
			IValue reifiedType = args[0];
			TypeStore ts = new TypeStore(); // start afresh
			IValueFactory values = getEval().getValueFactory();
			Type rt = new TypeReifier(values).valueToType((IConstructor) reifiedType, ts);

			Convert.declareRefType(ts);
			
			IValue val = Convert.obj2value(model, rt, values, ts, src);
			return ResultFactory.makeResult(rt, val, getEval());
		}

		

	}
}
