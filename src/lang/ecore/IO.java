package lang.ecore;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

import org.eclipse.core.filesystem.EFS;
import org.eclipse.core.filesystem.IFileStore;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IWorkspaceRoot;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.emf.common.command.CompoundCommand;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.eclipse.emf.edit.domain.EditingDomain;
import org.eclipse.emf.edit.domain.IEditingDomainProvider;
import org.eclipse.swt.widgets.Display;
import org.eclipse.ui.IEditorDescriptor;
import org.eclipse.ui.IEditorInput;
import org.eclipse.ui.IEditorPart;
import org.eclipse.ui.IWorkbench;
import org.eclipse.ui.IWorkbenchPage;
import org.eclipse.ui.IWorkbenchWindow;
import org.eclipse.ui.PartInitException;
import org.eclipse.ui.PlatformUI;
import org.eclipse.ui.ide.IDE;
import org.eclipse.ui.part.FileEditorInput;
import org.rascalmpl.debug.IRascalMonitor;
import org.rascalmpl.interpreter.IEvaluator;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.TypeReifier;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.result.AbstractFunction;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.types.FunctionType;
import org.rascalmpl.interpreter.types.RascalTypeFactory;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.uri.URIEditorInput;
import org.rascalmpl.uri.URIResolverRegistry;
import org.rascalmpl.uri.URIStorage;
import org.rascalmpl.values.uptr.RascalValueFactory;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.INode;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;

/**
 * This class provide a load method to get an ADT from an EMF model
 */
public class IO {
	private final IValueFactory vf;
	private final TypeReifier tr;
	
	/*
	 * Public Rascal interface
	 */
	
	public IO(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("*", new XMIResourceFactoryImpl());
	}
	
	public IEditorPart getEditorFor(ISourceLocation loc, IEvaluatorContext ctx) throws PartInitException, IOException {
		IEditorDescriptor desc = PlatformUI.getWorkbench().getEditorRegistry().getDefaultEditor(loc.getPath());
		final List<IEditorPart> l = new ArrayList<>();
		if (desc != null) {
			URIResolverRegistry reg = URIResolverRegistry.getInstance();
			final ISourceLocation theLoc = reg.logicalToPhysical(loc);
			
			IWorkbench wb = PlatformUI.getWorkbench();
			IWorkbenchWindow win = wb.getActiveWorkbenchWindow();
			
			if (win == null && wb.getWorkbenchWindowCount() != 0) {
				win = wb.getWorkbenchWindows()[0];
			}
			
			IWorkbenchPage page = win.getActivePage();
			
			Display.getDefault().syncExec(new Runnable() {
               public void run() {
				try {
					IEditorPart editor = page.openEditor(getEditorInput(theLoc.getURI()), desc.getId());
					l.add(editor);
				} catch (PartInitException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
               }
            });
			
		} else {
			IFileStore fileStore = EFS.getLocalFileSystem().getStore(loc.getURI());
			IWorkbenchPage page = PlatformUI.getWorkbench().getActiveWorkbenchWindow().getActivePage();
			l.add(IDE.openEditorOnFileStore(page, fileStore));
		}
		
		return l.get(0);
	}
	
	private IEditorInput getEditorInput(java.net.URI uri) {
		String scheme = uri.getScheme();

		if (scheme.equals("project")) {
			IProject project = ResourcesPlugin.getWorkspace().getRoot().getProject(uri.getAuthority());

			if (project != null) {
				return new FileEditorInput(project.getFile(uri.getPath()));
			}
		} 
		else if (scheme.equals("file")) {
			IWorkspaceRoot root = ResourcesPlugin.getWorkspace().getRoot();
			IFile[] cs = root.findFilesForLocationURI(uri);

			if (cs != null && cs.length > 0) {
				return new FileEditorInput(cs[0]);
			}
		}

		URIStorage storage = new URIStorage(vf.sourceLocation(uri));
		return new URIEditorInput(storage);
	}
	
	
	public ICallableValue editor(IValue reifiedType, ISourceLocation loc, IValue reifiedPatchType, IEvaluatorContext ctx) {
		TypeStore ts = new TypeStore();
		Type modelType = tr.valueToType((IConstructor) reifiedType, ts);
		Type patchType = tr.valueToType((IConstructor) reifiedPatchType, ts); 
		Convert.declareRefType(ts);
		try {
			IEditorPart editor = getEditorFor(loc, ctx);
			IEditingDomainProvider prov = (IEditingDomainProvider) editor;
			EditingDomain domain = prov.getEditingDomain();
			return new EditorClosure(() -> {
				// obtain the model from the editor and return it.
				// FIXME: find a more reliable to get the root model.
				Resource res = domain.getResourceSet().getResources().get(0);
				return res.getContents().get(0);
			}, domain, modelType, patchType, ts, loc, ctx.getEvaluator());
		} catch (PartInitException | IOException e) {
			throw RuntimeExceptionFactory.io(vf.string(e.getMessage()), null, null);
		}
	}
	
	public IValue load(ISourceLocation pkgUri, IValue ecoreType) {
		java.net.URI uri = pkgUri.getURI();
		EPackage pkg = EPackage.Registry.INSTANCE.getEPackage(uri.toString());
		TypeStore ts = new TypeStore(); // start afresh

		Type rt = tr.valueToType((IConstructor) ecoreType, ts);
		Convert.declareRefType(ts);
		return Convert.obj2value(pkg, rt, vf, ts, vf.sourceLocation(uri));
	}
	
	public IValue load(IValue reifiedType, ISourceLocation uri) {
		TypeStore ts = new TypeStore(); // start afresh

		Type rt = tr.valueToType((IConstructor) reifiedType, ts);
		Convert.declareRefType(ts);
		try {
			EObject root = loadModel(uri);
			return Convert.obj2value(root, rt, vf, ts, uri);
		} catch (IOException e) {
			throw RuntimeExceptionFactory.io(vf.string("could not load model at " + uri), null, null);
		}
		
		
	}
	
	public void save(INode model, ISourceLocation uri, ISourceLocation pkgUri) {
		EPackage pkg = EPackage.Registry.INSTANCE.getEPackage(pkgUri.getURI().toString());
		EObject root = Convert.value2obj(pkg, (IConstructor) model);
		try {
			saveModel(root, uri);
		} catch (IOException e) {
			throw RuntimeExceptionFactory.io(vf.string(e.getMessage()), null, null);
		}
	}
	
	private static void saveModel(EObject model, ISourceLocation uri) throws IOException {
		ResourceSet rs = new ResourceSetImpl();
		Resource res = rs.createResource(URI.createURI(uri.getURI().toString()));
		URIResolverRegistry reg = URIResolverRegistry.getInstance();
		res.getContents().add(model);
		res.save(reg.getOutputStream(uri, false), Collections.EMPTY_MAP);
	}
	

	
	private static EObject loadModel(ISourceLocation uri) throws IOException {
		ResourceSet rs = new ResourceSetImpl();
		Resource res = rs.getResource(URI.createURI(uri.getURI().toString()), true);
		URIResolverRegistry reg = URIResolverRegistry.getInstance();
		res.load(reg.getInputStream(uri), Collections.emptyMap());
		return res.getContents().get(0);
	}


	private static class EditorClosure extends AbstractFunction {

		private Supplier<EObject> model;
		private Type modelType;
		private TypeStore ts;
		private EditingDomain domain;
		private ISourceLocation src;
		
		private static final RascalTypeFactory rtf = RascalTypeFactory.getInstance();
		private static final TypeFactory tf = TypeFactory.getInstance();
		
		private static FunctionType myType(Type patchType) {
			// type = void(Patch(&T<:node));
			Type param = tf.parameterType("T", tf.nodeType());
			Type closureType = rtf.functionType(patchType, tf.tupleType(param) , null);
			FunctionType myType = (FunctionType) rtf.functionType(tf.voidType(),  tf.tupleType(closureType), null);
			return myType;
		}
		
		public EditorClosure(Supplier<EObject> model, EditingDomain domain, Type modelType, Type patchType, TypeStore ts, ISourceLocation src, IEvaluator<Result<IValue>> eval) {
			super(null, eval, myType(patchType), Collections.emptyList(), false, eval.getCurrentEnvt());
			this.model = model;
			this.domain = domain;
			this.modelType = modelType;
			this.ts = ts;
			this.src = src;
		}

		@Override
		public ICallableValue cloneInto(Environment arg0) {
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
		public Result<IValue> call(IRascalMonitor arg0, Type[] arg1, IValue[] arg2, Map<String, IValue> arg3) {
			return call(arg1, arg2, arg3);
		}
		
		@Override
		public Result<IValue> call(Type[] arg0, IValue[] args, Map<String, IValue> kws) {
			ICallableValue argClosure = (ICallableValue)args[0];
			EObject obj = model.get();
			IValue modelValue = Convert.obj2value(obj, modelType, getEval().getValueFactory(), ts, src);
			ITuple patch = (ITuple) argClosure.call(new Type[] {modelType}, new IValue[] { modelValue }, Collections.emptyMap()).getValue();
			CompoundCommand cmd = EMFBridge.patch(domain, obj, patch);
			domain.getCommandStack().execute(cmd);
			return null; 
		}
		
		@Override
		public IConstructor encodeAsConstructor() {
			IValueFactory vf = eval.getValueFactory();
			return vf.constructor(RascalValueFactory.Function_Function, vf.sourceLocation("file:///unknown"));
		}
		
	}
	
}
