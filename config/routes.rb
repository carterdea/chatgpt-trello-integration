Rails.application.routes.draw do
  post '/tickets', to: 'tickets#create'
  get '/trello-powerup', to: 'trello_powerup#index'
end