Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "documents#index"

  get "s/:share_token", to: "documents#shared_present", as: :shared_present

  resources :documents, only: %i[index new create show update destroy] do
    member do
      get  :present
      get  :status
      get  :download_pdf
      post :retry_convert
      post :verify_password
    end
  end
end
