Rails.application.routes.draw do
  post '/tickets', to: 'tickets#create'
end