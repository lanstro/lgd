// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.


$(document).ready(function(){
	
	if($('#act').length > 0){
		$('body').scrollspy({ target: '#sidebar' });
		Lgd.start();
	}

});
