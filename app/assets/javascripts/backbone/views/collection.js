var Lgd = Lgd || {};

Lgd.ActView = Backbone.View.extend({
	el: '#backbone',

	initialize: function(){
		this.collection= Lgd.act;
		this.collection.fetch();
		
		_.bindAll(this, 'render');

		this.render();
		
		this.listenTo(this.collection, "sync", this.render);

		// bind creation of index for autocomplete to sync
	},
	render: function(){
		this.$el.empty();
		this.collection.each(function(container){
			var containerView = new Lgd.ContainerView({ model: container });
			this.$el.append(containerView.el);
		}, this);
	}
	
	
	
})