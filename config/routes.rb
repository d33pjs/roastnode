Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "home#index"
  get "dashboard" => "home#dashboard", as: :dashboard
  resource :profile, only: %i[edit update]
  resource :workspace_onboarding, only: %i[new create]
  resources :workspaces, only: [] do
    patch :switch, on: :member
  end
  resources :memberships, only: :index
  resources :workspace_invites, only: %i[index create show], param: :token do
    post :accept, on: :member
    patch :revoke, on: :member
  end
  resources :beans, only: %i[index new create show edit update destroy] do
    patch :close, on: :member
    patch :reopen, on: :member
    post :duplicate, on: :member
  end
  resources :equipment, only: %i[index new create show]
  resources :equipment_events, only: %i[new create show]
  resources :preparation_tools, only: %i[index new create]
  resources :brews, only: %i[new create show edit update destroy]
  get "statistics" => "statistics#index", as: :statistics
  resources :media_attachments, only: %i[show destroy]
  resource :workspace_export, only: :show
  resources :beanconqueror_imports, only: %i[new create show]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
