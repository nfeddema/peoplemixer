Rails.application.routes.draw do
  get 'operations/home'
  get 'operations/set_quantity'
  get 'operations/display_form'
  get 'operations/display_results'
  get 'operations/download_file'
  post 'operations/calculate'

  root 'operations#home'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
