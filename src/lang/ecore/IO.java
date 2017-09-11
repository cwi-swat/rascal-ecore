package lang.ecore;

import java.io.IOException;
import java.util.Collections;

import org.eclipse.core.resources.IResource;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.rascalmpl.interpreter.TypeReifier;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.uri.URIResourceResolver;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.INode;
import io.usethesource.vallang.ISourceLocation;
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
	private static final TypeFactory tf = TypeFactory.getInstance();
	
	/*
	 * Public Rascal interface
	 */
	
	public IO(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("*", new XMIResourceFactoryImpl());
	}
	
	
	public IValue load(IValue reifiedType, ISourceLocation uri) {
		TypeStore ts = new TypeStore(); // start afresh

		Type rt = tr.valueToType((IConstructor) reifiedType, ts);

		// Cheat: build Ref  here (assuming Id is in there)
		Type refType = tf.abstractDataType(ts, "Ref", tf.parameterType("T"));
		tf.constructor(ts, refType, "ref", ts.lookupAbstractDataType("Id"), "uid");
		tf.constructor(ts, refType, "null");
		
		EObject root = loadModel(uri);
		
		return Convert.obj2value(root, rt, vf, ts);
	}
	
	public void save(INode model, ISourceLocation uri) {
		ISourceLocation pkgUri = (ISourceLocation) ((IConstructor)model).get("pkgURI");
		EPackage pkg = EPackage.Registry.INSTANCE.getEPackage(pkgUri.getURI().toString());

		Convert.ModelBuilder builder = new Convert.ModelBuilder(pkg);
		EObject root = (EObject) model.accept(builder);

		// FIXME: Actually, when encountering a ref(id(_)) in the tree,
		// it should be possible to get the type it refers to,
		// create a placeholder object for it, and later fill the
		// structural features when encountering the real object.
		// Thus, getting rid of the second traversal.
		// >>> TVDS: this will not work, since the Reffed type will not be the concrete class.
		
		Convert.CrossRefResolver resolver = new Convert.CrossRefResolver(builder.getUids());
		model.accept(resolver);
		
		saveModel(root, uri);
	}

	/*
	 * For calling rascal from the EMF side
	 */
	
	
	private void saveModel(EObject model, ISourceLocation uri) {
		ResourceSet rs = new ResourceSetImpl();
		IResource resource = URIResourceResolver.getResource(uri);
		java.net.URI eclipseURI = resource.getRawLocationURI();

		Resource res = rs.createResource(URI.createURI(eclipseURI.toString()));
		res.getContents().add(model);
		try {
			res.save(Collections.EMPTY_MAP);
		} catch (IOException e) {
			throw RuntimeExceptionFactory.io(vf.string(e.getMessage()), null, null);
		}
	}
	

	
	private static EObject loadModel(ISourceLocation uri) {
		IResource resource = URIResourceResolver.getResource(uri);
		java.net.URI eclipseURI = resource.getRawLocationURI();

		ResourceSet rs = new ResourceSetImpl();
		Resource res = rs.getResource(URI.createURI(eclipseURI.toString()), true);
		return res.getContents().get(0);
	}


	

}
