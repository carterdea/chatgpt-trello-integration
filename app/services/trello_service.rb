require 'httparty'

class TrelloService
  include HTTParty
  base_uri 'https://api.trello.com/1'

  def initialize
    @auth = { key: ENV['TRELLO_API_KEY'], token: ENV['TRELLO_TOKEN'] }
    @board_id = ENV['TRELLO_BOARD_ID']
  end

  def get_list_id(column_name)
    response = self.class.get("/boards/#{@board_id}/lists", query: @auth)
    return nil unless response.success?

    list = response.parsed_response.find { |l| l['name'].casecmp?(column_name) }
    list ? list['id'] : nil
  end

  def create_card(client, title, description, assignee, column)
    list_id = get_list_id(column)
    return { error: "Column '#{column}' not found" } unless list_id

    response = self.class.post("/cards", query: @auth.merge({
      idList: list_id,
      name: "#{client} - #{title}",
      desc: description
    }))

    return { error: "Failed to create card" } unless response.success?

    { ticket_url: response.parsed_response['shortUrl'], details: { client:, title:, description:, assignee:, column: } }
  end
end