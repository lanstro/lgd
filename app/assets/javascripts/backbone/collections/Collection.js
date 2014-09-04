var Lgd = Lgd || {};

Lgd.Collection = Backbone.Collection.extend ({
	model: Lgd.Container,
	initialize: function(){
		this.url=$('.legislation').data('legislation_id')+'/containers_json.json';
	},
	
	comparator: 'id'
});