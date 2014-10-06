if(typeof(CKEDITOR) != 'undefined') {
	
	CKEDITOR.editorConfig = function(config){


		config.toolbar_Comment = [
			{ name: 'document',                                                     items: [ 'Source', 'Preview'] },
			{ name: 'clipboard',   groups: [ 'clipboard', 'undo' ],                 items: [ 'Cut', 'Copy', 'Paste', 'PasteText', 'PasteFromWord', '-', 'Undo', 'Redo' ] },
			{ name: 'editing',     groups: [ 'find', 'selection', 'spellchecker' ], items: [ 'Find', 'Replace', '-', 'SelectAll', '-', 'Scayt' ] },
			{ name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ],            items: [ 'Bold', 'Italic', 'Underline', 'Strike', 'Subscript', 'Superscript', '-', 'RemoveFormat' ] },
			{ name: 'paragraph',   groups: [ 'list', 'indent', 'blocks', 'align'],  items: [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'Blockquote', 'CreateDiv', '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock'] },
			{ name: 'links',                                                        items: [ 'Link', 'Unlink', 'Anchor' ] },
			{ name: 'tools', items: [ 'Maximize', 'ShowBlocks' ] },
			
		];
		
		config.toolbar = 'Comment';
	}
}
else {
	console.log("ckeditor not loaded");
}
