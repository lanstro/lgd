// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

$(document).ready(function(){
	$('body').scrollspy({ target: '#sidebar' });
	Lgd = Lgd || {};
	Lgd.act  = new Lgd.Collection();
	Lgd.view = new Lgd.ActView();
	Lgd.quickNav = new Lgd.QuickNav();
	
	// this goes into the sync function for the collection
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
