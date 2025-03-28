# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  use_doorkeeper do
    controllers applications: "oauth/applications",
      authorized_applications: "oauth/authorized_applications"
  end

  resources :comments
  resources :devices
  resources :teams

  root to: "topics#index"
  match "/uploads/:path(![large|lg|md|sm|xs])", to: "home#uploads", via: :get, constraints: {
    path: /[\w\d.\/\-]+/i
  }
  get "status", to: "home#status"
  get "manifest.webmanifest", to: "home#manifest"

  devise_for :users, path: "account", controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    passwords: "users/passwords",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  resource :setting do
    member do
      get :account
      get :password
      get :profile
      get :reward
    end
  end

  # SSO
  namespace :auth do
    resource :sso, controller: "sso" do
      collection do
        get :login
        get :provider
      end
    end
  end

  delete "setting/auth/:provider", to: "settings#auth_unbind", as: "auth_unbind_setting"

  resources :nodes do
    member do
      post :block
      post :unblock
    end
  end

  get "topics/node:id", to: "topics#node", as: "node_topics"
  get "topics/node:id/feed", to: "topics#node_feed", as: "feed_node_topics", defaults: {format: "xml"}

  resources :topics do
    member do
      post :favorite
      delete :unfavorite
      post :follow
      delete :unfollow
      post :action
      # ban popup window
      get :ban
      post :read
    end

    collection do
      get :no_reply
      get :popular
      get :last
      get :last_reply
      get :banned
      get :excellent
      get :favorites
      get :feed, defaults: {format: "xml"}
      post :preview
    end

    resources :replies do
      member do
        get :reply_to
      end
    end
  end

  resources :photos
  resources :likes

  get "/search", to: "search#index", as: "search"
  get "/search/users", to: "search#users", as: "search_users"

  namespace :admin do
    root to: "dashboards#index", as: "root"
    resource :dashboards do
      collection do
        post :reboot
      end
    end
    resources :site_configs
    resources :replies do
      member do
        post :revert
      end
    end
    resources :topics do
      member do
        post :suggest
        post :unsuggest
        post :revert
      end
    end
    resources :nodes
    resources :users, constraints: {id: /[#{User::LOGIN_FORMAT}]*/o} do
      member do
        delete :clean
      end
    end
    resources :photos
    resources :comments
    resources :locations
    resources :applications
    resources :stats
    resources :plugins
  end

  get "api", to: "home#api", as: "api"
  get "markdown", to: "home#markdown", as: "markdown"

  namespace :api do
    namespace :v3 do
      get "hello", to: "root#hello"

      resource :devices
      resource :likes
      resources :nodes
      resources :photos
      resources :notifications do
        collection do
          post :read
          get :unread_count
          delete :all
        end
      end
      resources :topics do
        member do
          post :update
          get :replies
          post :replies
          post :follow
          post :unfollow
          post :favorite
          post :unfavorite
          post :ban
          post :action
        end
      end
      resources :replies do
        member do
          post :update
        end
      end
      resources :users do
        collection do
          get :me
        end
        member do
          get :topics
          get :replies
          get :favorites
          get :followers
          get :following
          get :blocked
          post :follow
          post :unfollow
          post :block
          post :unblock
        end
      end

      match "*path", to: "root#not_found", via: :all
    end
  end

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web, at: "sidekiq"
    mount PgHero::Engine, at: "pghero"
    mount ExceptionTrack::Engine, at: "exception-track"
  end

  mount Notifications::Engine, at: "notifications"

  # WARRING！请保持 User 的 routes 在所有路由的最后，以便于可以让用户名在根目录下面使用，而又不影响到其他的 routes
  # 比如 http://localhost:3000/huacnlee
  get "users/city/:id", to: "users#city", as: "location_users"
  get "users", to: "users#index", as: "users"

  constraints(id: /[#{User::LOGIN_FORMAT}]*/o) do
    resources :users, path: "", as: "users" do
      member do
        get :feed
        # User only
        get :topics
        get :replies
        get :favorites
        get :blocked
        post :block
        post :unblock
        post :follow
        post :unfollow
        get :followers
        get :following
        get :reward
      end

      resources :team_users, path: "people" do
        member do
          post :accept
          post :reject
        end
      end
    end
  end

  match "*path", to: "home#error_404", via: :all
end
