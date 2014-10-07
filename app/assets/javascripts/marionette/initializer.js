
var Lgd = new Marionette.Application();

Lgd.addRegions({
	MainViewRegion: "#legislation_main",
	SideNavRegion: "#sidebar",
	ModesRegion: "#secondary"
});

$(document).ready(function(){
	
	Lgd.on('start', function(options){
		console.log("Lgd app controllers initializing");
		Lgd.MainView.Controller.initialize();
		Lgd.Modes.Controller.initialize();
		Lgd.SideNav.Controller.initialize();
		
		
	});
});