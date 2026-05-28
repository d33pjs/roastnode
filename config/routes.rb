Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "home#index"
  get "dashboard" => "home#dashboard", as: :dashboard
  get "instance_admin" => "instance_admin#index", as: :instance_admin
  namespace :instance_admin, path: "instance_admin" do
    resources :backup_profiles, only: %i[create update] do
      post :run, on: :member
    end
  end
  resource :profile, only: %i[edit update]
  resource :workspace, only: %i[edit update]
  resource :workspace_onboarding, only: %i[new create]
  resources :workspaces, only: [] do
    patch :switch, on: :member
  end
  resources :memberships, only: :index
  resources :workspace_invites, only: %i[index create show], param: :token do
    post :accept, on: :member
    post :signup, on: :member
    patch :revoke, on: :member
  end
  resources :beans, only: %i[index new create show edit update destroy] do
    patch :finish, on: :member
    patch :close, on: :member
    patch :reopen, on: :member
    post :duplicate, on: :member
    resources :inventory_adjustments, only: %i[new create]
  end
  resources :equipment, only: %i[index new create show edit update destroy] do
    patch :archive, on: :member
    patch :reopen, on: :member
  end
  resources :equipment_events, only: %i[new create show edit update destroy]
  resources :preparation_tools, only: %i[index new create show edit update destroy] do
    patch :archive, on: :member
    patch :reopen, on: :member
  end
  resources :brews, only: %i[new create show edit update destroy]
  get "statistics" => "statistics#index", as: :statistics
  resources :media_attachments, only: %i[show destroy] do
    match :crop, on: :member, via: %i[get patch]
    get :download, on: :member
    patch :primary, on: :member
  end
  resource :workspace_export, only: :show
  get "workspace_export/beans.csv" => "workspace_exports#beans", as: :workspace_export_beans
  get "workspace_export/brews.csv" => "workspace_exports#brews", as: :workspace_export_brews
  get "workspace_export/media.zip" => "workspace_exports#media", as: :workspace_export_media
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
