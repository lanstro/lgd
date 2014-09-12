var Lgd = Lgd || {};

Lgd.Collection = Backbone.Collection.extend ({
	model: Lgd.Container,
	comparator: 'position',
	initialize: function(){
		this.url=$('.legislation').data('legislation_id')+'/containers_json.json';
	},
	
	findParent: function(container){
		if(typeof(container)==="undefined") return null;
		var parent_id = container.get('parent_id');
		if(!parent_id) return null;
		return this.models.find(function(model){
			return model.get('id')==parent_id;
		});
	},
	
	findChildren: function(container){
		if(typeof(container)==="undefined" || !container){
			console.log("undefined findChildren argument");
			return null;
		}
		if(container=="root"){
			console.log("finding root children");
			id = null;
		}
		else{
			console.log("finding children for "+container.get('content'));
			var id = container.get('id');
		}
		// TODO MEDIUM - need much better algorithm
		return this.models.filter(function(model){
			return model.get('parent_id')==id;
		});
	}
	
	
});