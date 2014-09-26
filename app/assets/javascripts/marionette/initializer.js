
var Lgd = new Marionette.Application();

console.log("Lgd app initialized");

Lgd.addRegions({
	MainViewRegion: "#act_main",
	SideNavRegion: "#sidebar",
	ModesRegion: "#modes"
});

$(document).ready(function(){
	
	Lgd.on('start', function(options){
		
		Lgd.MainView.Controller.initialize();
		Lgd.Modes.Controller.initialize();
		Lgd.SideNav.Controller.initialize();
		
		
	});
});