var Lgd = Lgd || {};

Lgd.ContainerView = Backbone.View.extend ({
	tagName: 'div',
	id: function(){
		return this.model.get('id');
	},
	
	className: function(){
		return this.model.get('depth');
	},
	
	initialize: function(){
		this.template=JST['backbone/templates/container'];
		this.render();
	},
	
	render: function(){
		this.$el.html(this.template(this.model.toJSON()));
		return this;
	},
	
});