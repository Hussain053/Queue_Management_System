Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'health', to: 'health#show'
      post 'auth/login', to: 'auth#create'
      delete 'auth/logout', to: 'auth#destroy'
      get 'auth/me', to: 'auth#show'
      get 'display/:queue_id', to: 'queue_displays#show'
      resources :queues, only: %i[index show] do
        member do
          get :dashboard
          get :tokens
          post :call_next
          patch :settings
          get :reports
        end
        post 'tokens', to: 'tokens#create'
      end
      get 'tokens/:public_lookup_token', to: 'public_tokens#show', as: :public_token
      patch 'tokens/:id/:operation', to: 'token_actions#update', constraints: { operation: /complete|skip|return_to_waiting|cancel/ }
    end
  end
end
