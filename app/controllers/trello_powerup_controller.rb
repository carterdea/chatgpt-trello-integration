class TrelloPowerupController < ApplicationController
  def index
    render file: Rails.root.join('public', 'trello_powerup.html'), layout: false
  end
end