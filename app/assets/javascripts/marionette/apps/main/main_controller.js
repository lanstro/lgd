Lgd.module('MainView', function(Mainview, Lgd, Backbone, Marionette, $, _){
	
	Mainview.Controller = {
		
		initialize: function(){
			
			// initialize Act
			
			var act = Lgd.request("Act");
			
			var contentView = new Mainview.Act({
				collection: act
			});
			act.on("sync", function(){
				console.log("picked up sync - showing mainview");
				Lgd.MainViewRegion.show(contentView);
			});
			act.fetch();
			
			// mouseover highlight
			
			var mouseOveredElements = [];
			var highlightedContainer;
			
			Lgd.on("container:mouseEnter", function(element){
				mouseOveredElements.push(element);
				element.addClass("highlighted");
				if(highlightedContainer){
					highlightedContainer.removeClass("highlighted");
				}
				highlightedContainer = element;
			});
			Lgd.on("container:mouseLeave", function(element){
				element.removeClass("highlighted");
				mouseOveredElements = _.without(mouseOveredElements, element);
				
				if(highlightedContainer == element){
					highlightedContainer=null;
					var last = _.last(mouseOveredElements);
					if(last){
						highlightedContainer=last;
						last.addClass("highlighted");
					}
				}
				
			});
			
			
		},
		
		
	}
});


