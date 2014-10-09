
var Lgd = new Marionette.Application();

Lgd.addRegions({
	MainViewRegion:  "#legislation_main",
	SideNavRegion:   "#sidebar_div",
	SecondaryRegion: "#secondary"
});

$(document).ready(function(){
	
	Lgd.on('start', function(options){
		console.log("Lgd app controllers initializing");
		Lgd.MainView.Controller.initialize();
		Lgd.Secondary.Controller.initialize();
		Lgd.SideNav.Controller.initialize();
		
		
	});
});