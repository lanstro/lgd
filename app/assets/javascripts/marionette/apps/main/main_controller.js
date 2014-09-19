Lgd.module('MainView', function(Mainview, Lgd, Backbone, Marionette, $, _){
	
	Mainview.Controller = {
		initialize: function(){
			var act = Lgd.request("Act");
			var contentView = new Mainview.Act({
				collection: act
			});
			act.on("sync", function(){
				console.log("picked up sync");
				Lgd.MainViewRegion.show(contentView);
			});
			act.fetch();
		}
	}
});


