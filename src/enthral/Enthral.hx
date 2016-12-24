package enthral;

import js.Browser;
import js.Promise;
import js.html.*;
import enthral.Component;
import enthral.PropTypes;
import SystemJs;
using haxe.io.Path;

class Enthral {
	public function new() {}

	public function instantiateComponent<T>(componentScriptUrl:String, componentDataUrl:String, container:Element):Promise<StaticComponent<T>> {
		var scriptPromise = SystemJs.importJs(componentScriptUrl).then(loadModuleDependencies),
			dataPromise = Browser.window.fetch(componentDataUrl).then(function (resp:Response) {
				return resp.json().then(function (data) {
					data.enthral = {
						scriptUrl: componentScriptUrl,
						scriptPath: componentScriptUrl.directory().addTrailingSlash(),
						dataUrl: componentDataUrl,
						dataPath: componentDataUrl.directory().addTrailingSlash()
					};
					return data;
				});
			});
		return Promise.all([scriptPromise, dataPromise]).then(function (arr:Array<Dynamic>) {
			return mountComponent(arr[0], arr[1], container);
		});
	}

	/**
		Given a loaded module, see if an `enthralDependencies` object exists.
		If it does, load each of the dependencies, and return a promise for once they are ready to go.
	**/
	function loadModuleDependencies(module:Dynamic):Promise<Module> {
		// TODO: use an abstract here instead of Dynamic and Reflect. ObjectMap isn't quite what we need either.
		var loadedDependencies:Dynamic<Module> = {},
			promises = [];
		if (module.enthralDependencies != null) {
			var deps:Dynamic<String> = module.enthralDependencies;
			for (name in Reflect.fields(deps)) {
				var url = Reflect.field(deps, name);
				var depLoaded = SystemJs.importJs(url).then(function (dep:Module) {
					Reflect.setField(loadedDependencies, name, dep);
				});
				promises.push(depLoaded);
			}
		}
		return Promise.all(promises).then(function (_) {
			module.enthralLoadedDependencies = loadedDependencies;
			return module;
		});
	}

	function mountComponent<T>(componentCls:Module, componentData:T, container:Element):StaticComponent<T> {
		var dependencies = (componentCls:Dynamic).enthralLoadedDependencies,
			schema = (componentCls:Dynamic).enthralPropTypes,
			enthralData = (componentData:Dynamic).enthral;
		if (schema != null) {
			PropTypes.validate(schema, componentData, enthralData.dataUrl);
		}

		var component:StaticComponent<T> = componentCls.instantiate(componentData, dependencies);
		component.setupView(container);
		return component;
	}
}
