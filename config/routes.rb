# == Route Map
#
#              Prefix Verb   URI Pattern                             Controller#Action
#                root GET    /                                       static_pages#home
#                help GET    /help(.:format)                         static_pages#help
#               about GET    /about(.:format)                        static_pages#about
#              signup GET    /signup(.:format)                       users#new
#              signin GET    /signin(.:format)                       sessions#new
#             signout DELETE /signout(.:format)                      sessions#destroy
#               users GET    /users(.:format)                        users#index
#                     POST   /users(.:format)                        users#create
#            new_user GET    /users/new(.:format)                    users#new
#           edit_user GET    /users/:id/edit(.:format)               users#edit
#                user GET    /users/:id(.:format)                    users#show
#                     PATCH  /users/:id(.:format)                    users#update
#                     PUT    /users/:id(.:format)                    users#update
#                     DELETE /users/:id(.:format)                    users#destroy
#            sessions POST   /sessions(.:format)                     sessions#create
#         new_session GET    /sessions/new(.:format)                 sessions#new
#             session DELETE /sessions/:id(.:format)                 sessions#destroy
#           parse_act GET    /acts/:id/parse(.:format)               acts#parse
#   reset_parsing_act GET    /acts/:id/reset_parsing(.:format)       acts#reset_parsing
# containers_json_act GET    /acts/:id/containers_json(.:format)     acts#containers_json
#                acts GET    /acts(.:format)                         acts#index
#                     POST   /acts(.:format)                         acts#create
#             new_act GET    /acts/new(.:format)                     acts#new
#            edit_act GET    /acts/:id/edit(.:format)                acts#edit
#                 act GET    /acts/:id(.:format)                     acts#show
#                     PATCH  /acts/:id(.:format)                     acts#update
#                     PUT    /acts/:id(.:format)                     acts#update
#                     DELETE /acts/:id(.:format)                     acts#destroy
#          containers GET    /containers(.:format)                   containers#index
#                     POST   /containers(.:format)                   containers#create
#       new_container GET    /containers/new(.:format)               containers#new
#      edit_container GET    /containers/:id/edit(.:format)          containers#edit
#           container GET    /containers/:id(.:format)               containers#show
#                     PATCH  /containers/:id(.:format)               containers#update
#                     PUT    /containers/:id(.:format)               containers#update
#                     DELETE /containers/:id(.:format)               containers#destroy
#            comments GET    /comments(.:format)                     comments#index
#                     POST   /comments(.:format)                     comments#create
#        edit_comment GET    /comments/:id/edit(.:format)            comments#edit
#             comment PATCH  /comments/:id(.:format)                 comments#update
#                     PUT    /comments/:id(.:format)                 comments#update
#                     DELETE /comments/:id(.:format)                 comments#destroy
#         new_comment GET    /comments/new(/:parent_id)(.:format)    comments#new
#                     GET    /comments/for_container(/:id)(.:format) comments#get_comments_by_container
#

Lgd::Application.routes.draw do
  get "metadatum/new"
  get "metadatum/edit"
  get "metadatum/delete"
  get "metadatum/update"
  get "metadatum/create"
  get "metadatum/show"
  get "metadatum/index"
  # static pages
  root "static_pages#home"
  match "/help",   to: "static_pages#help",  via: "get"
	match "/about",  to: "static_pages#about", via: "get"
	
	# users
	devise_for :users, :controllers => { omniauth_callbacks: 'omniauth_callbacks'}
	match '/users/:id/finish_signup' => 'users#finish_signup', via: [:get, :patch], :as => :finish_signup
	
	# acts and containers
	resources :acts do 
		member do
			get 'parse'
			get 'reset_parsing'
			get 'containers_json'
		end
	end
	
	match '/show_json/:id' => 'containers#show_json', via: [:get]
	
	#comments 
	resources :comments, only: [:create, :destroy, :edit, :update, :hide, :index]
	post '/comments/(:parent_id)/new', to: 'comments#create'
	get '/acts/(:act_id)/comments_json/(:container_id)', to: 'comments#get_comments_by_container'
	
	#metadata
	resources :metadata,            controller: 'metadatum', type: 'Metadatum'
	resources :internal_references, controller: 'metadatum', type: 'Internal_reference'
	resources :definitions,         controller: 'metadatum', type: 'Definition'
	resources :hyperlinks,          controller: 'metadatum', type: 'Hyperlink'
	
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
