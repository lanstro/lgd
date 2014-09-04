var Lgd = Lgd || {};

Lgd.ActView = Backbone.View.extend({
	el: '#backbone',

	initialize: function(){
		this.collection= new Lgd.Collection();
		this.collection.fetch();
		this.subViews = [];
		
		_.bindAll(this, 'render');

		this.render();
		
		// bind render to sync
		// bind creation of index to sync
	},
	render: function(){
		this.$el.empty();
		this.collection.each(function(container){
			var containerView = new Lgd.ContainerView({ model: container });
			this.$el.append(containerView.el);
		}, this);
	}
	
	
	
})