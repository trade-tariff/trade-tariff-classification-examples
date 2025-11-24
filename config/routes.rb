# frozen_string_literal: true

Rails.application.routes.draw do
  get 'healthcheckz' => 'rails/health#show', as: :rails_health_check

  root 'homepage#index'

  get '/search_commodities', to: 'search_commodities#show', as: :search_commodities_get
  post '/search_commodities', to: 'search_commodities#show', as: :search_commodities

  resources :basic_sessions, only: %i[new create]

  match '/400', to: 'errors#bad_request', via: :all
  match '/404', to: 'errors#not_found', via: :all, as: :not_found
  match '/405', to: 'errors#method_not_allowed', via: :all
  match '/406', to: 'errors#not_acceptable', via: :all
  match '/422', to: 'errors#unprocessable_entity', via: :all
  match '/429', to: 'errors#too_many_requests', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
  match '/501', to: 'errors#not_implemented', via: :all
  match '/503', to: 'errors#maintenance', via: :all
  match '*path', to: 'errors#not_found', via: :all
end
