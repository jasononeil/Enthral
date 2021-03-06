import js.Browser.document;
import js.Browser.window;
import js.html.*;
import js.Promise;
import js.codemirror.*;
import haxe.Json;
import enthraler.proptypes.*;
import enthraler.EnthralerMessages;

/**
The entry point for a JS file that renders an editor for an Enthraler.
**/
class EnthralerEditor {
	public static function main() {
		EnthralerHost.addMessageListeners();
		var params = getParamsFromLocation();
		loadEnthralerEditor(params);
	}

	static function getParamsFromLocation() {
		var hash = window.location.hash;
		var paramStrings = hash.substr(hash.indexOf('?') + 1).split('&');
		var params = new Map();
		for (str in paramStrings) {
			var parts = str.split('=');
			params[parts[0]] = parts[1];
		}
		return params;
	}

	static function loadEnthralerEditor(params:Map<String,String>) {
		var templateUrl = params['template'],
			schemaUrl = params['schema'],
			dataUrl = params['authorData'];

		var preview:IFrameElement = cast document.getElementById('preview'),
			textarea:TextAreaElement = cast document.getElementById('textarea'),
			errorList:UListElement = cast document.getElementById('error-list');

		preview.src = '/bin/frame.html#?template=' + templateUrl + '&authorData=' + dataUrl;

		var dataText = window.fetch(dataUrl).then(function (r) return r.text()),
			schemaObj = loadSchema(schemaUrl);

		var editor = dataText.then(function (data) {
			textarea.value = data;
			return CodeMirror.fromTextArea(textarea, cast {
				mode: 'application/json',
				lineNumbers: true,
				foldGutter: true,
				gutters: ["CodeMirror-linenumbers", "CodeMirror-foldgutter", "CodeMirror-lint-markers"],
				lint: true
			});
		});

		js.Promise.all([editor, schemaObj]).then(function (arr:Array<Dynamic>) {
			var editor:CodeMirror = arr[0],
				schema:PropTypes = arr[1];

			editor.on('change', function () {
				var newJson = editor.getValue(),
					validationResult = null,
					authorData = null;

				try {
					authorData = Json.parse(newJson);
					if (schema != null) {
						validationResult = Validators.validate(schema, authorData, 'live JSON editor');
					}
				} catch (e:Dynamic) {
					validationResult = [new Validators.ValidationError('JSON syntax error: ' + e, AccessProperty('document'))];
				}


				if (validationResult == null) {
					// The new authorData is valid
					errorList.classList.add('hidden');
					preview.contentWindow.postMessage(Json.stringify({
						src: '' + window.location,
						context: EnthralerMessages.receiveAuthorData,
						authorData: authorData
					}), preview.contentWindow.location.origin);
				} else {
					function addError(ve:Validators.ValidationError) {
						var li = document.createLIElement();
						li.innerHTML = '<strong>${ve.getErrorPath()}</strong>: ${ve.message}';
						errorList.appendChild(li);
						for (childError in ve.childErrors) {
							addError(childError);
						}
					}
					// Show a validation error
					errorList.innerHTML = '';
					errorList.classList.remove('hidden');
					for (e in validationResult) {
						addError(e);
					}
				}
			});
		});
	}

	static function loadSchema(schemaUrl: String): Promise<Dynamic> {
		return window
			.fetch(schemaUrl)
			.then(function (r) return r.json())
			.catchError(function (e) {
				trace('Failed to load schema: ', e);
				return null;
			});
	}
}
