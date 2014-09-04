// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

$(document).ready(function(){
	$('body').scrollspy({ target: '#sidebar' });
	Lgd = Lgd || {};
	Lgd.view = new Lgd.ActView();
	$("#quicknav").autocomplete({ 
		autoFocus: true,
		delay:     100,
		minLength: 2,
		source:    function(request, response) {
			var results = $.ui.autocomplete.filter(["to be added"], request.term);
			response(results.slice(0, 10));
		}
	})
});
