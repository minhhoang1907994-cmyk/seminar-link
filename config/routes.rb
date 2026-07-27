Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "documents#index"

  resources :documents, only: %i[index new create show update destroy] do
    member do
      get  :present
      post :retry_convert
      post :verify_password
    end
  end
end
