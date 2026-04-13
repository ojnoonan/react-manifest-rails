Rails.application.routes.draw do
  root "dashboard#index"

  resources :users
  resources :products
  resources :orders
  resources :notifications, only: [:index, :show]
  resources :reports, only: [:index]

  resource :settings, only: [:show, :update]

  namespace :admin do
    root "dashboard#index"
    resources :users
    resources :dashboard, only: [:index, :show]
  end

  get  "/login",    to: "auth#login",    as: :login
  post "/login",    to: "auth#create"
  get  "/register", to: "auth#register", as: :register
  post "/register", to: "auth#signup"
  delete "/logout", to: "auth#destroy",  as: :logout
end
